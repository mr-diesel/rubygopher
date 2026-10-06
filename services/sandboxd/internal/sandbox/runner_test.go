package sandbox

import (
	"context"
	"errors"
	"os/exec"
	"path/filepath"
	"slices"
	"strings"
	"testing"
	"time"
)

func sh(script string) spec {
	return spec{argv: []string{"sh", "-c", script}}
}

func TestExecuteKillsOnTimeout(t *testing.T) {
	started := time.Now()
	_, err := execute(context.Background(), 200*time.Millisecond, 1024, sh("sleep 5"))

	if !errors.Is(err, errTimeout) {
		t.Fatalf("err = %v, want errTimeout", err)
	}
	if elapsed := time.Since(started); elapsed > 2*time.Second {
		t.Errorf("took %s, the process group was not killed", elapsed)
	}
}

func TestExecuteKillsChildrenOfTheSnippet(t *testing.T) {
	started := time.Now()
	_, err := execute(context.Background(), 200*time.Millisecond, 1024, sh("sh -c 'sleep 5' & wait"))

	if !errors.Is(err, errTimeout) {
		t.Fatalf("err = %v, want errTimeout", err)
	}
	if elapsed := time.Since(started); elapsed > 2*time.Second {
		t.Errorf("took %s, the grandchild survived", elapsed)
	}
}

func TestExecuteDoesNotWaitForOrphans(t *testing.T) {
	started := time.Now()
	out, err := execute(context.Background(), 5*time.Second, 1024, sh("sleep 3 & echo hi"))

	if err != nil {
		t.Fatal(err)
	}
	if string(out.stdout) != "hi\n" {
		t.Errorf("stdout = %q", out.stdout)
	}
	if elapsed := time.Since(started); elapsed > 2*time.Second {
		t.Errorf("took %s, waited for the orphaned child", elapsed)
	}
}

func TestExecuteReportsExternalKill(t *testing.T) {
	_, err := execute(context.Background(), 5*time.Second, 1024, sh("kill -9 $$"))

	if !errors.Is(err, errKilled) {
		t.Fatalf("err = %v, want errKilled", err)
	}
}

func TestExecuteCapsOutput(t *testing.T) {
	out, err := execute(context.Background(), 5*time.Second, 1000, sh("yes | head -c 100000"))

	if err != nil {
		t.Fatal(err)
	}
	if len(out.stdout) != 1000 {
		t.Errorf("kept %d bytes, want 1000", len(out.stdout))
	}
}

func TestExecuteTreatsNonZeroExitAsResult(t *testing.T) {
	out, err := execute(context.Background(), 5*time.Second, 1024, sh("echo boom >&2; exit 3"))

	if err != nil {
		t.Fatalf("err = %v, want nil", err)
	}
	if string(out.stderr) != "boom\n" || out.exit != 3 {
		t.Errorf("stderr = %q, exit = %d", out.stderr, out.exit)
	}
}

func TestExecuteAppliesDirAndEnv(t *testing.T) {
	out, err := execute(context.Background(), 5*time.Second, 1024, spec{
		dir:  "/",
		env:  []string{"PATH=/usr/bin:/bin", "GREETING=hi"},
		argv: []string{"sh", "-c", "pwd; echo $GREETING"},
	})

	if err != nil {
		t.Fatal(err)
	}
	if string(out.stdout) != "/\nhi\n" {
		t.Errorf("stdout = %q", out.stdout)
	}
}

func TestCommandForRuby(t *testing.T) {
	r := &Runner{Ruby: "/usr/local/bin/ruby", Evaluator: "/app/evaluator.rb"}
	s := r.command("ruby", "/tmp/snippet.rb", 5*time.Second)

	want := []string{"/usr/local/bin/ruby", "-r", "/app/evaluator.rb", "-e", boot, "/tmp/snippet.rb", "5"}
	if !slices.Equal(s.argv, want) {
		t.Errorf("argv = %q", s.argv)
	}
	if s.dir != "" || len(s.env) != len(baseEnv) {
		t.Errorf("ruby context must run with no dir and a minimal env, got dir=%q env=%q", s.dir, s.env)
	}
}

func TestCommandForRailsPassesOnlyAllowedEnv(t *testing.T) {
	t.Setenv("DB_HOST", "sandbox_db")
	t.Setenv("SANDBOX_TOKEN", "secret")

	r := &Runner{RailsRoot: "/app"}
	s := r.command("rails", "/tmp/snippet.rb", 7*time.Second)

	if s.dir != "/app" || s.argv[0] != "bin/rails" || s.argv[len(s.argv)-1] != "7" {
		t.Errorf("unexpected spec: %+v", s)
	}
	if !slices.Contains(s.env, "DB_HOST=sandbox_db") {
		t.Errorf("DB_HOST missing from env %q", s.env)
	}
	for _, kv := range s.env {
		if strings.HasPrefix(kv, "SANDBOX_TOKEN=") {
			t.Errorf("the supervisor's own secrets leaked into the child env")
		}
	}
}

func TestRunRejectsUnknownContext(t *testing.T) {
	_, err := (&Runner{}).Run(context.Background(), "p 1", "python", time.Second)

	if err == nil {
		t.Fatal("expected an error")
	}
}

func TestParseFallsBackToStderr(t *testing.T) {
	result := parse([]byte("not json"), []byte("ruby: no such file\n"))

	if result.Error == nil || result.Error.Class != "ConsoleError" || result.Error.Message != "ruby: no such file" {
		t.Errorf("unexpected result: %+v", result)
	}
}

func TestParseReadsEvaluatorVerdict(t *testing.T) {
	result := parse([]byte(`{"output":"2\n","error":{"class":"ArgumentError","message":"boom","backtrace":["(console):1"]}}`), nil)

	if result.Output != "2\n" || result.Error == nil || result.Error.Class != "ArgumentError" {
		t.Errorf("unexpected result: %+v", result)
	}
}

func TestRunGoReportsBuildRunAndTimeout(t *testing.T) {
	goBin, err := exec.LookPath("go")
	if err != nil {
		t.Skip("go is not installed")
	}
	runner := &Runner{Go: goBin, MaxOutput: 1 << 20}

	cases := []struct {
		name, code, class, output string
		timeout                   time.Duration
	}{
		{"prints", "package main\nimport \"fmt\"\nfunc main() { fmt.Println(\"hi\") }", "", "hi\n", 10 * time.Second},
		{"build error", "package main\nfunc main() { undefined() }", "BuildError", "", 10 * time.Second},
		{"panic", "package main\nfunc main() { panic(\"boom\") }", "ExitError", "panic: boom", 10 * time.Second},
		{"timeout keeps output", "package main\nimport (\"fmt\"; \"time\")\nfunc main() { fmt.Println(\"partial\"); time.Sleep(time.Minute) }", "Timeout", "partial\n", time.Second},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			result, err := runner.Run(context.Background(), tc.code, "go", tc.timeout)
			if err != nil {
				t.Fatal(err)
			}
			class := ""
			if result.Error != nil {
				class = result.Error.Class
			}
			if class != tc.class || !strings.Contains(result.Output, tc.output) {
				t.Errorf("got class=%q output=%q, want class=%q output containing %q", class, result.Output, tc.class, tc.output)
			}
		})
	}
}

func TestRunWithRealRuby(t *testing.T) {
	ruby, err := exec.LookPath("ruby")
	evaluator, _ := filepath.Abs("../../../../backend/app/domains/playground/evaluator.rb")
	if err != nil {
		t.Skip("ruby is not installed")
	}

	runner := &Runner{Ruby: ruby, Evaluator: evaluator, MaxOutput: 1 << 20}
	result, err := runner.Run(context.Background(), "p 1 + 1\nraise ArgumentError, 'boom'", "ruby", 5*time.Second)

	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "2\n" || result.Error == nil || result.Error.Class != "ArgumentError" {
		t.Errorf("unexpected result: %+v", result)
	}
}
