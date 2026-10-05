package sandbox

import (
	"context"
	"errors"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestExecuteKillsOnTimeout(t *testing.T) {
	started := time.Now()
	_, _, err := execute(context.Background(), 200*time.Millisecond, 1024, "sh", "-c", "sleep 5")

	if !errors.Is(err, errTimeout) {
		t.Fatalf("err = %v, want errTimeout", err)
	}
	if elapsed := time.Since(started); elapsed > 2*time.Second {
		t.Errorf("took %s, the process group was not killed", elapsed)
	}
}

func TestExecuteKillsChildrenOfTheSnippet(t *testing.T) {
	started := time.Now()
	_, _, err := execute(context.Background(), 200*time.Millisecond, 1024, "sh", "-c", "sh -c 'sleep 5' & wait")

	if !errors.Is(err, errTimeout) {
		t.Fatalf("err = %v, want errTimeout", err)
	}
	if elapsed := time.Since(started); elapsed > 2*time.Second {
		t.Errorf("took %s, the grandchild survived", elapsed)
	}
}

func TestExecuteDoesNotWaitForOrphans(t *testing.T) {
	started := time.Now()
	stdout, _, err := execute(context.Background(), 5*time.Second, 1024, "sh", "-c", "sleep 3 & echo hi")

	if err != nil {
		t.Fatal(err)
	}
	if string(stdout) != "hi\n" {
		t.Errorf("stdout = %q", stdout)
	}
	if elapsed := time.Since(started); elapsed > 2*time.Second {
		t.Errorf("took %s, waited for the orphaned child", elapsed)
	}
}

func TestExecuteReportsExternalKill(t *testing.T) {
	_, _, err := execute(context.Background(), 5*time.Second, 1024, "sh", "-c", "kill -9 $$")

	if !errors.Is(err, errKilled) {
		t.Fatalf("err = %v, want errKilled", err)
	}
}

func TestExecuteCapsOutput(t *testing.T) {
	stdout, _, err := execute(context.Background(), 5*time.Second, 1000, "sh", "-c", "yes | head -c 100000")

	if err != nil {
		t.Fatal(err)
	}
	if len(stdout) != 1000 {
		t.Errorf("kept %d bytes, want 1000", len(stdout))
	}
}

func TestExecuteTreatsNonZeroExitAsResult(t *testing.T) {
	_, stderr, err := execute(context.Background(), 5*time.Second, 1024, "sh", "-c", "echo boom >&2; exit 3")

	if err != nil {
		t.Fatalf("err = %v, want nil", err)
	}
	if string(stderr) != "boom\n" {
		t.Errorf("stderr = %q", stderr)
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

func TestRunWithRealRuby(t *testing.T) {
	ruby, err := exec.LookPath("ruby")
	evaluator, _ := filepath.Abs("../../../../backend/app/domains/playground/evaluator.rb")
	if err != nil {
		t.Skip("ruby is not installed")
	}

	runner := &Runner{Ruby: ruby, Evaluator: evaluator, MaxOutput: 1 << 20}
	result, err := runner.Run(context.Background(), "p 1 + 1\nraise ArgumentError, 'boom'", 5*time.Second)

	if err != nil {
		t.Fatal(err)
	}
	if result.Output != "2\n" || result.Error == nil || result.Error.Class != "ArgumentError" {
		t.Errorf("unexpected result: %+v", result)
	}
}
