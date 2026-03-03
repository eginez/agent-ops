// agent-loop — run OpenCode sessions in a loop, optionally inside a Docker Sandbox.
//
// Sandbox creation is handled by scripts/sandbox-bootstrap.sh.
// Each iteration starts a fresh OpenCode session. The agent is expected to emit
// a promise sentinel in its output to signal the loop what to do next:
//
//	<promise>PROGRESS</promise>   — continue to next iteration
//	<promise>COMPLETE</promise>   — stop, all tasks done
//	<promise>BLOCKED:reason</promise> — stop, needs human input
//	<promise>DECIDE:question</promise> — stop, needs a design decision
package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strings"
	"syscall"
	"time"
)

// ANSI color codes used in banner/progress output.
const (
	colorBlue   = "\033[0;34m"
	colorGreen  = "\033[0;32m"
	colorRed    = "\033[0;31m"
	colorYellow = "\033[1;33m"
	colorReset  = "\033[0m"
)

// version is set at build time via -ldflags "-X main.version=<tag>".
var version = "dev"

// sentinel regexes compiled once.
var (
	reBlocked = regexp.MustCompile(`<promise>BLOCKED:([^<]+)</promise>`)
	reDecide  = regexp.MustCompile(`<promise>DECIDE:([^<]+)</promise>`)
)

// loopResult describes why an iteration ended.
type loopResult int

const (
	resultProgress    loopResult = iota // keep going
	resultComplete                      // all done
	resultBlocked                       // needs human input
	resultDecide                        // needs a decision
	resultError                         // agent error / no sentinel
	resultInterrupted                   // killed by signal
)

func generatePrompt() string {
	return "You are autonomous agent, your task is to complete a development task. " +
		"Start by reading the AGENTS.md and then look for " +
		"documents/guides/SESSION_PROTOCOL.md — understand session workflow. Begin work now"
}

// getWorkspacePath queries `docker sandbox ls --json` and returns the first
// workspace path registered for sandboxName.
func getWorkspacePath(sandboxName string) (string, error) {
	out, err := exec.Command("docker", "sandbox", "ls", "--json").Output()
	if err != nil {
		return "", fmt.Errorf("docker sandbox ls: %w", err)
	}

	var result struct {
		VMs []struct {
			Name       string   `json:"name"`
			Workspaces []string `json:"workspaces"`
		} `json:"vms"`
	}
	if err := json.Unmarshal(out, &result); err != nil {
		return "", fmt.Errorf("parse docker sandbox ls output: %w", err)
	}

	for _, vm := range result.VMs {
		if vm.Name == sandboxName && len(vm.Workspaces) > 0 {
			return vm.Workspaces[0], nil
		}
	}
	return "", fmt.Errorf("no workspace found for sandbox %q", sandboxName)
}

// buildCmd constructs the opencode command for this iteration.
func buildCmd(useSandbox bool, sandboxName, workdir, prompt string) (*exec.Cmd, error) {
	if useSandbox {
		workspacePath, err := getWorkspacePath(sandboxName)
		if err != nil {
			return nil, err
		}
		slog.Info("resolved sandbox workspace", "sandbox", sandboxName, "workspace", workspacePath)
		// docker sandbox exec <name> opencode run --dir <path> "<prompt>"
		return exec.Command("docker", "sandbox", "exec", sandboxName,
			"opencode", "run", "--dir", workspacePath, prompt), nil
	}

	dir := workdir
	if dir == "" {
		var err error
		dir, err = os.Getwd()
		if err != nil {
			return nil, fmt.Errorf("getwd: %w", err)
		}
	}
	slog.Info("running locally", "workdir", dir)
	return exec.Command("opencode", "run", "--dir", dir, prompt), nil
}

// runIteration executes one agent session and streams its output to stdout.
// It returns a loopResult indicating what the agent signalled, plus any error.
// kill is closed by the caller to forcibly terminate the subprocess mid-run.
func runIteration(iteration, maxIterations int, useSandbox bool, sandboxName, workdir, prompt string, kill <-chan struct{}) (loopResult, error) {
	iterDisplay := "∞"
	if maxIterations > 0 {
		iterDisplay = fmt.Sprintf("%d", maxIterations)
	}

	fmt.Printf("%s[loop]%s ═══════════════════════════════════════════\n", colorBlue, colorReset)
	fmt.Printf("%s[loop]%s Iteration %d of %s\n", colorBlue, colorReset, iteration, iterDisplay)
	fmt.Printf("%s[loop]%s ═══════════════════════════════════════════\n", colorBlue, colorReset)

	slog.Info("starting iteration", "iteration", iteration, "max_iterations", iterDisplay)

	cmd, err := buildCmd(useSandbox, sandboxName, workdir, prompt)
	if err != nil {
		return resultError, fmt.Errorf("build command: %w", err)
	}

	cmd.Stdout = nil // we'll read via pipe below
	cmd.Stderr = os.Stderr

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return resultError, fmt.Errorf("stdout pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		return resultError, fmt.Errorf("start agent: %w", err)
	}

	// Watch for a force-kill signal. procDone is closed once we leave the
	// scanning loop so the goroutine doesn't outlive this function.
	procDone := make(chan struct{})
	go func() {
		select {
		case <-kill:
			slog.Warn("force-killing agent subprocess")
			fmt.Printf("\n%s[loop]%s Interrupted — killing agent...\n", colorRed, colorReset)
			if useSandbox {
				// The local cmd is just the `docker sandbox exec` client;
				// opencode runs inside the sandbox and must be killed there.
				killCmd := exec.Command("docker", "sandbox", "exec", sandboxName,
					"pkill", "-9", "-f", "opencode")
				if err := killCmd.Run(); err != nil {
					slog.Warn("pkill opencode in sandbox failed", "err", err)
				}
			}
			// Also kill the local docker/opencode process.
			if cmd.Process != nil {
				_ = cmd.Process.Kill()
			}
		case <-procDone:
		}
	}()

	var buf strings.Builder
	scanner := bufio.NewScanner(stdout)
	result := resultError // default if no sentinel found

	for scanner.Scan() {
		line := scanner.Text()
		fmt.Println(line)
		buf.WriteString(line)
		buf.WriteByte('\n')

		accumulated := buf.String()

		switch {
		case strings.Contains(accumulated, "<promise>COMPLETE</promise>"):
			slog.Info("sentinel received", "sentinel", "COMPLETE")
			fmt.Printf("\n%s[loop]%s ALL TASKS COMPLETE\n", colorGreen, colorReset)
			result = resultComplete
			goto done

		case strings.Contains(accumulated, "<promise>BLOCKED:"):
			match := reBlocked.FindStringSubmatch(accumulated)
			reason := "unknown"
			if len(match) > 1 {
				reason = match[1]
			}
			slog.Warn("sentinel received", "sentinel", "BLOCKED", "reason", reason)
			fmt.Printf("\n%s[loop]%s BLOCKED: %s\n", colorRed, colorReset, reason)
			result = resultBlocked
			goto done

		case strings.Contains(accumulated, "<promise>DECIDE:"):
			match := reDecide.FindStringSubmatch(accumulated)
			question := "unknown"
			if len(match) > 1 {
				question = match[1]
			}
			slog.Warn("sentinel received", "sentinel", "DECIDE", "question", question)
			fmt.Printf("\n%s[loop]%s DECISION NEEDED: %s\n", colorYellow, colorReset, question)
			result = resultDecide
			goto done

		case strings.Contains(accumulated, "<promise>PROGRESS</promise>"):
			slog.Info("sentinel received", "sentinel", "PROGRESS")
			fmt.Printf("\n%s[loop]%s Task completed, continuing...\n", colorGreen, colorReset)
			result = resultProgress
			goto done
		}
	}

done:
	close(procDone) // signal kill-watcher to exit

	// Drain stdout so the process can exit cleanly.
	for scanner.Scan() {
	}

	if err := cmd.Wait(); err != nil {
		// Check if we killed it ourselves via the kill channel.
		select {
		case <-kill:
			return resultInterrupted, nil
		default:
		}
		// If we already have a sentinel result, the exit code is less important
		// (the process may exit non-zero after we've already decided to stop).
		if result == resultError {
			slog.Error("agent exited with error", "err", err)
			fmt.Printf("%s[loop]%s Agent exited with error: %v\n", colorRed, colorReset, err)
			return resultError, nil
		}
		slog.Warn("agent exited non-zero after sentinel", "err", err)
	}

	if result == resultError {
		slog.Error("agent finished without a promise sentinel")
		fmt.Printf("%s[loop]%s Agent finished without a promise sentinel\n", colorRed, colorReset)
	}

	return result, nil
}

func main() {
	// --- flags ---
	var (
		maxIterations int
		once          bool
		noSandbox     bool
		workdir       string
		sandboxFlag   string
		promptFlag    string
		printVersion  bool
	)

	flag.BoolVar(&printVersion, "version", false, "Print version and exit")
	flag.IntVar(&maxIterations, "n", 0, "Maximum number of iterations (0 = unlimited)")
	flag.BoolVar(&once, "once", false, "Run a single iteration")
	flag.BoolVar(&noSandbox, "no-sandbox", false, "Run without Docker Sandbox (uses --workdir or cwd)")
	flag.StringVar(&workdir, "workdir", "", "Working directory when running without a sandbox (default: cwd)")
	flag.StringVar(&sandboxFlag, "sandbox", os.Getenv("RUDDER_SANDBOX"), "Sandbox name (or set RUDDER_SANDBOX env var)")
	flag.StringVar(&promptFlag, "prompt", "", "Prompt for the agent (prefix with @ to read from a file)")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: agent-loop [options] [sandbox-name]\n\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\nPromise sentinels the agent should emit:\n")
		fmt.Fprintf(os.Stderr, "  <promise>PROGRESS</promise>       continue to next iteration\n")
		fmt.Fprintf(os.Stderr, "  <promise>COMPLETE</promise>        stop — all tasks done\n")
		fmt.Fprintf(os.Stderr, "  <promise>BLOCKED:reason</promise>  stop — needs human input\n")
		fmt.Fprintf(os.Stderr, "  <promise>DECIDE:q</promise>        stop — needs a design decision\n")
	}

	flag.Parse()

	if printVersion {
		fmt.Printf("agent-loop %s\n", version)
		os.Exit(0)
	}

	// Positional arg overrides --sandbox.
	if flag.NArg() > 0 {
		sandboxFlag = flag.Arg(0)
	}

	// Handle --once.
	if once {
		maxIterations = 1
	}

	// Resolve prompt.
	prompt := promptFlag
	if strings.HasPrefix(prompt, "@") {
		filePath := prompt[1:]
		data, err := os.ReadFile(filePath)
		if err != nil {
			slog.Error("cannot read prompt file", "path", filePath, "err", err)
			os.Exit(1)
		}
		prompt = string(data)
	}
	if prompt == "" {
		prompt = generatePrompt()
	}

	// Validate sandbox requirement.
	useSandbox := !noSandbox
	sandboxName := sandboxFlag
	if useSandbox && sandboxName == "" {
		fmt.Fprintln(os.Stderr, "Error: sandbox name is required (or use --no-sandbox to run locally)")
		flag.Usage()
		os.Exit(1)
	}

	// --- banner ---
	iterDisplay := "∞"
	if maxIterations > 0 {
		iterDisplay = fmt.Sprintf("%d", maxIterations)
	}
	sandboxDisplay := sandboxName
	if sandboxDisplay == "" {
		sandboxDisplay = "(none)"
	}

	fmt.Printf("%s╔══════════════════════════════════════╗%s\n", colorBlue, colorReset)
	fmt.Printf("%s║      Agentic Loop                    ║%s\n", colorBlue, colorReset)
	fmt.Printf("%s║  Iterations: %-3s                     ║%s\n", colorBlue, iterDisplay, colorReset)
	fmt.Printf("%s║  Sandbox: %-25s║%s\n", colorBlue, sandboxDisplay, colorReset)
	fmt.Printf("%s╚══════════════════════════════════════╝%s\n\n", colorBlue, colorReset)

	slog.Info("agent-loop starting",
		"max_iterations", iterDisplay,
		"sandbox", sandboxDisplay,
		"use_sandbox", useSandbox,
	)

	// --- signal handling ---
	// Ctrl-C closes killProc, which kills the running subprocess immediately.
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, os.Interrupt, syscall.SIGTERM)

	killProc := make(chan struct{})

	go func() {
		defer signal.Stop(sigs)
		<-sigs
		fmt.Printf("\n%s[loop]%s Interrupted — killing agent...\n", colorRed, colorReset)
		slog.Warn("interrupt received, killing subprocess")
		close(killProc)
	}()

	// --- main loop ---
	for i := 1; maxIterations == 0 || i <= maxIterations; i++ {
		res, err := runIteration(i, maxIterations, useSandbox, sandboxName, workdir, prompt, killProc)
		if err != nil {
			slog.Error("iteration error", "iteration", i, "err", err)
			fmt.Printf("%s[loop]%s Error: %v\n", colorRed, colorReset, err)
			fmt.Printf("%s[loop]%s Loop stopped at iteration %d.\n", colorBlue, colorReset, i)
			break
		}

		if res == resultInterrupted {
			fmt.Printf("%s[loop]%s Loop interrupted at iteration %d.\n", colorYellow, colorReset, i)
			break
		}

		if res != resultProgress {
			fmt.Printf("%s[loop]%s Loop stopped at iteration %d.\n", colorBlue, colorReset, i)
			break
		}

		atLimit := maxIterations > 0 && i >= maxIterations
		if !atLimit {
			slog.Info("pausing between iterations", "seconds", 5)
			fmt.Printf("%s[loop]%s Pausing 5s...\n", colorBlue, colorReset)
			select {
			case <-time.After(5 * time.Second):
			case <-killProc:
				goto exit
			}
		}
	}

exit:
	fmt.Println()
	fmt.Printf("%s[loop]%s Done.\n", colorBlue, colorReset)
	fmt.Printf("%s[loop]%s Progress:   cat progress.txt\n", colorBlue, colorReset)
	fmt.Printf("%s[loop]%s Remaining:  cat documents/tasks/tasks.json | jq '.tasks[] | select(.passes==false)'\n", colorBlue, colorReset)
}
