package api

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"rubygopher/sandboxd/internal/sandbox"
)

type fakeRunner struct {
	mu      sync.Mutex
	timeout time.Duration
	block   chan struct{}
}

func (f *fakeRunner) Run(_ context.Context, code string, timeout time.Duration) (sandbox.Result, error) {
	f.mu.Lock()
	f.timeout = timeout
	f.mu.Unlock()
	if f.block != nil {
		<-f.block
	}
	return sandbox.Result{Output: "ran: " + code}, nil
}

func post(h http.Handler, body string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/eval", strings.NewReader(body)))
	return rec
}

func newHandler(runner Runner, parallel int) http.Handler {
	return NewHandler(runner, slog.New(slog.DiscardHandler), parallel)
}

func TestEvalReturnsRunnerResult(t *testing.T) {
	rec := post(newHandler(&fakeRunner{}, 1), `{"code":"p 1"}`)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var body evalResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Output != "ran: p 1" || body.Context != "ruby" || body.Error != nil {
		t.Errorf("unexpected body: %+v", body)
	}
}

func TestEvalDefaultsTimeout(t *testing.T) {
	runner := &fakeRunner{}
	post(newHandler(runner, 1), `{"code":"p 1"}`)

	if runner.timeout != 5*time.Second {
		t.Errorf("timeout = %s, want 5s", runner.timeout)
	}
}

func TestEvalRejectsBadInput(t *testing.T) {
	cases := map[string]string{
		"not json":        `{`,
		"empty code":      `{"code":""}`,
		"timeout too big": `{"code":"p 1","timeout":31}`,
		"other context":   `{"code":"p 1","context":"rails"}`,
		"huge code":       `{"code":"` + strings.Repeat("x", maxCodeBytes+1) + `"}`,
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			if rec := post(newHandler(&fakeRunner{}, 1), body); rec.Code != http.StatusBadRequest {
				t.Errorf("status = %d, want 400", rec.Code)
			}
		})
	}
}

func TestEvalRefusesWhenBusy(t *testing.T) {
	runner := &fakeRunner{block: make(chan struct{})}
	h := newHandler(runner, 1)

	first := make(chan int)
	go func() { first <- post(h, `{"code":"sleep"}`).Code }()
	time.Sleep(50 * time.Millisecond)

	if rec := post(h, `{"code":"p 1"}`); rec.Code != http.StatusServiceUnavailable {
		t.Errorf("second request status = %d, want 503", rec.Code)
	}

	close(runner.block)
	if code := <-first; code != http.StatusOK {
		t.Errorf("first request status = %d, want 200", code)
	}
}
