# Expose Agent Loop Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `--expose` flag to `agent-loop` that binds the local opencode server to `0.0.0.0` for network access.

**Architecture:** Modify the `main.go` file to parse a new boolean flag `--expose`. Pass this boolean to the `startServe` function. Update `startServe` to append `--hostname 0.0.0.0` to the `opencode serve` arguments when the flag is true.

**Tech Stack:** Go 1.21+

---

### Task 1: Add `--expose` flag to `main.go`

**Files:**
- Modify: `src/cmd/agent-loop/main.go`

- [ ] **Step 1: Declare the `expose` flag**
Find the `var` block for flags (around line 451) and add `expose bool`.

```go
	var (
		maxIterations int
		once          bool
		noSandbox     bool
		yolo          bool
		everyFlag     string
		workdir       string
		sandboxFlag   string
		promptFlag    string
		printVersion  bool
		port          int
		expose        bool
	)
```

- [ ] **Step 2: Parse the flag**
Find the `flag.BoolVar` definitions (around line 464) and add the definition for `--expose`.

```go
	flag.BoolVar(&expose, "expose", false, "Expose the local opencode server to the network (binds to 0.0.0.0)")
```

- [ ] **Step 3: Commit**

```bash
git add src/cmd/agent-loop/main.go
git commit -m "feat: add --expose flag definition"
```

### Task 2: Update `startServe` function

**Files:**
- Modify: `src/cmd/agent-loop/main.go`

- [ ] **Step 1: Update the `startServe` signature and command building**
Find the `startServe` function (around line 231). Update its signature to accept `expose bool`. Then dynamically build the `exec.Command` arguments to include `--hostname 0.0.0.0` if `expose` is true.

```go
func startServe(port int, expose bool, workdir string, yolo bool) (string, *exec.Cmd, error) {
	args := []string{"serve", "--port", strconv.Itoa(port)}
	if expose {
		args = append(args, "--hostname", "0.0.0.0")
	}
	cmd := exec.Command("opencode", args...)
	if workdir != "" {
		cmd.Dir = workdir
	}
	if yolo {
		cmd.Env = append(os.Environ(), `OPENCODE_PERMISSION={"*":"allow"}`)
	}
	cmd.Stderr = os.Stderr

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return "", nil, fmt.Errorf("serve stdout pipe: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return "", nil, fmt.Errorf("start opencode serve: %w", err)
	}

	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, "listening on") {
			parts := strings.Fields(line)
			url := parts[len(parts)-1]
			go io.Copy(io.Discard, stdout) // drain so the process doesn't block
			return url, cmd, nil
		}
	}
	_ = cmd.Process.Kill()
	return "", nil, fmt.Errorf("opencode serve exited before printing a URL")
}
```

- [ ] **Step 2: Update the `startServe` call site**
Find the call to `startServe` in `main()` (around line 576) and pass the new `expose` flag.

```go
		fmt.Printf("%s[loop]%s Starting opencode server on port %d...\n", colorBlue, colorReset, port)
		url, serveCmd, err := startServe(port, expose, dir, yolo)
		if err != nil {
```

- [ ] **Step 3: Run the compiler to verify there are no syntax errors**

```bash
make build
```
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add src/cmd/agent-loop/main.go
git commit -m "feat: implement --expose behavior for opencode server"
```
