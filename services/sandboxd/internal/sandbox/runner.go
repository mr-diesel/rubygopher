package sandbox

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"strings"
	"syscall"
	"time"
)

// Error is a pointer so a clean run serialises as "error": null, like the Rails runners.
type Result struct {
	Output string `json:"output"`
	Error  *Error `json:"error"`
}

type Error struct {
	Class     string   `json:"class"`
	Message   string   `json:"message"`
	Backtrace []string `json:"backtrace,omitempty"`
}

type Runner struct {
	Ruby      string
	Evaluator string
	MaxOutput int64
}

const boot = "print JSON.generate(Playground::Evaluator.run(File.read(ARGV[0])))"

const stderrTail = 2000

var (
	errTimeout = errors.New("sandbox: timeout")
	errKilled  = errors.New("sandbox: killed")
)

func (r *Runner) Run(ctx context.Context, code string, timeout time.Duration) (Result, error) {
	file, err := os.CreateTemp("", "snippet-*.rb")
	if err != nil {
		return Result{}, err
	}
	defer os.Remove(file.Name())

	if _, err := file.WriteString(code); err != nil {
		return Result{}, err
	}
	if err := file.Close(); err != nil {
		return Result{}, err
	}

	stdout, stderr, err := execute(ctx, timeout, r.MaxOutput, r.Ruby, "-r", r.Evaluator, "-e", boot, file.Name())
	switch {
	case errors.Is(err, errTimeout):
		return timedOut(timeout), nil
	case errors.Is(err, errKilled):
		return killed(), nil
	case err != nil:
		return Result{}, err
	}
	return parse(stdout, stderr), nil
}

// A non-zero exit is not an error here: the evaluator already turned the snippet's
// failure into JSON. Only infrastructure problems come back as err.
func execute(ctx context.Context, timeout time.Duration, maxOutput int64, name string, args ...string) ([]byte, []byte, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Env = []string{"PATH=/usr/local/bin:/usr/bin:/bin", "LANG=C.UTF-8", "HOME=/tmp"}
	// Own process group: the kill reaches whatever the snippet forked, not just ruby.
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	// Forked children keep the pipes open after ruby exits; do not wait for them.
	cmd.WaitDelay = 500 * time.Millisecond

	stdout := &cappedBuffer{limit: maxOutput}
	stderr := &cappedBuffer{limit: maxOutput}
	cmd.Stdout = stdout
	cmd.Stderr = stderr

	runErr := cmd.Run()
	if cmd.Process != nil {
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
	}

	switch {
	case errors.Is(ctx.Err(), context.DeadlineExceeded):
		return stdout.Bytes(), stderr.Bytes(), errTimeout
	case runErr == nil, errors.Is(runErr, exec.ErrWaitDelay):
		return stdout.Bytes(), stderr.Bytes(), nil
	}

	var exitErr *exec.ExitError
	if !errors.As(runErr, &exitErr) {
		return stdout.Bytes(), stderr.Bytes(), runErr
	}
	// A SIGKILL we did not send is the cgroup OOM killer.
	if status, ok := exitErr.Sys().(syscall.WaitStatus); ok && status.Signaled() && status.Signal() == syscall.SIGKILL {
		return stdout.Bytes(), stderr.Bytes(), errKilled
	}
	return stdout.Bytes(), stderr.Bytes(), nil
}

func parse(stdout, stderr []byte) Result {
	var result Result
	if err := json.Unmarshal(stdout, &result); err != nil {
		message := strings.TrimSpace(string(tail(stderr, stderrTail)))
		if message == "" {
			message = "the ruby subprocess produced no result"
		}
		return Result{Error: &Error{Class: "ConsoleError", Message: message}}
	}
	return result
}

func timedOut(timeout time.Duration) Result {
	return Result{Error: &Error{
		Class:   "Timeout",
		Message: "execution exceeded " + timeout.String() + " — the process was killed",
	}}
}

func killed() Result {
	return Result{Error: &Error{
		Class:   "Killed",
		Message: "the process was killed before it finished — most likely it exceeded the memory limit",
	}}
}

func tail(b []byte, n int) []byte {
	if len(b) <= n {
		return b
	}
	return b[len(b)-n:]
}

// Keeps the first limit bytes and drops the rest without blocking, so a snippet
// printing forever runs into the timeout instead of wedging the pipe.
type cappedBuffer struct {
	limit int64
	buf   bytes.Buffer
}

func (b *cappedBuffer) Write(p []byte) (int, error) {
	if room := b.limit - int64(b.buf.Len()); room > 0 {
		if int64(len(p)) > room {
			p = p[:room]
		}
		b.buf.Write(p)
	}
	return len(p), nil
}

func (b *cappedBuffer) Bytes() []byte { return b.buf.Bytes() }
