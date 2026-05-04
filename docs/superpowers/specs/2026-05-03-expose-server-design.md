# Expose Agent Loop Server

## Purpose
Allow developers to easily expose the headless `opencode serve` process created by `agent-loop` to their local network, making it possible to connect to the session from other devices (like a mobile phone) or share it with other developers on the same network.

## Approach
Add a boolean `--expose` flag to the `agent-loop` CLI. When this flag is used, it instructs the embedded `opencode serve` command to bind to `0.0.0.0` instead of its default `127.0.0.1`.

## Changes

1. **Flag Definition**
   - Add a boolean variable `expose` in `main.go`.
   - Register the flag: `flag.BoolVar(&expose, "expose", false, "Expose the local opencode server to the network (binds to 0.0.0.0)")`.

2. **Server Execution**
   - Update `startServe` function signature to accept `expose bool`: 
     `func startServe(port int, expose bool, workdir string, yolo bool) (string, *exec.Cmd, error)`
   - Inside `startServe`, build the command dynamically:
     ```go
     args := []string{"serve", "--port", strconv.Itoa(port)}
     if expose {
         args = append(args, "--hostname", "0.0.0.0")
     }
     cmd := exec.Command("opencode", args...)
     ```

3. **Call Site**
   - Update the call to `startServe` in `main()` to pass the `expose` flag.