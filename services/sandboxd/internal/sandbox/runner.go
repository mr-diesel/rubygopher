package sandbox

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"strconv"
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
	RailsRoot string
	MaxOutput int64
}

const boot = "print JSON.generate(Playground::Evaluator.run(File.read(ARGV[0]), timeout: Integer(ARGV[1])))"

// The evaluator enforces the snippet timeout itself; the process deadline only adds
// room for interpreter boot and acts as the backstop when the snippet swallows it.
var bootAllowance = map[string]time.Duration{
	"ruby":  3 * time.Second,
	"rails": 20 * time.Second,
}

var railsEnv = []string{
	"RAILS_ENV", "RAILS_MASTER_KEY_PATH", "RAILS_MAX_THREADS", "SECRET_KEY_BASE", "DEVISE_JWT_SECRET_KEY",
	"DB_HOST", "DB_PORT", "DB_USERNAME", "DB_PASSWORD",
	"BUNDLE_PATH", "BUNDLE_APP_CONFIG", "GEM_HOME", "GEM_PATH",
}

const stderrTail = 2000

var (
	errTimeout = errors.New("sandbox: timeout")
	errKilled  = errors.New("sandbox: killed")
)

func Contexts() []string { return []string{"ruby", "rails"} }

func (r *Runner) Run(ctx context.Context, code, context string, timeout time.Duration) (Result, error) {
	allowance, ok := bootAllowance[context]
	if !ok {
		return Result{}, errors.New("sandbox: unknown context " + context)
	}

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

	stdout, stderr, err := execute(ctx, timeout+allowance, r.MaxOutput, r.command(context, file.Name(), timeout))
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

type spec struct {
	dir  string
	env  []string
	argv []string
}

func (r *Runner) command(context, file string, timeout time.Duration) spec {
	seconds := strconv.Itoa(int(timeout / time.Second))
	env := []string{"PATH=/usr/local/bin:/usr/bin:/bin", "LANG=C.UTF-8", "HOME=/tmp"}

	if context == "rails" {
		return spec{
			dir:  r.RailsRoot,
			env:  append(env, passthrough(railsEnv)...),
			argv: []string{"bin/rails", "runner", boot, file, seconds},
		}
	}
	return spec{env: env, argv: []string{r.Ruby, "-r", r.Evaluator, "-e", boot, file, seconds}}
}

func passthrough(keys []string) []string {
	var env []string
	for _, key := range keys {
		if value, ok := os.LookupEnv(key); ok {
			env = append(env, key+"="+value)
		}
	}
	return env
}

// A non-zero exit is not an error here: the evaluator already turned the snippet's
// failure into JSON. Only infrastructure problems come back as err.
func execute(ctx context.Context, deadline time.Duration, maxOutput int64, s spec) ([]byte, []byte, error) {
	ctx, cancel := context.WithTimeout(ctx, deadline)
	defer cancel()

	cmd := exec.CommandContext(ctx, s.argv[0], s.argv[1:]...)
	cmd.Dir = s.dir
	cmd.Env = s.env
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
