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
	context string
	timeout time.Duration
	block   chan struct{}
}

func (f *fakeRunner) Run(_ context.Context, code, context string, timeout time.Duration) (sandbox.Result, error) {
	f.mu.Lock()
	f.context, f.timeout = context, timeout
	f.mu.Unlock()
	if f.block != nil {
		<-f.block
	}
	return sandbox.Result{Output: "ran: " + code}, nil
}

func post(h http.Handler, body string, headers ...string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodPost, "/eval", strings.NewReader(body))
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func newHandler(runner Runner, cfg Config) http.Handler {
	if cfg.MaxParallel == 0 {
		cfg.MaxParallel = 1
	}
	return NewHandler(runner, slog.New(slog.DiscardHandler), cfg)
}

func TestEvalReturnsRunnerResult(t *testing.T) {
	rec := post(newHandler(&fakeRunner{}, Config{}), `{"code":"p 1"}`)

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

func TestEvalDefaultsTimeoutAndContext(t *testing.T) {
	runner := &fakeRunner{}
	post(newHandler(runner, Config{}), `{"code":"p 1"}`)

	if runner.timeout != 5*time.Second || runner.context != "ruby" {
		t.Errorf("timeout = %s, context = %q", runner.timeout, runner.context)
	}
}

func TestEvalPassesRailsContext(t *testing.T) {
	runner := &fakeRunner{}
	post(newHandler(runner, Config{}), `{"code":"p 1","context":"rails"}`)

	if runner.context != "rails" {
		t.Errorf("context = %q, want rails", runner.context)
	}
}

func TestEvalRejectsBadInput(t *testing.T) {
	cases := map[string]string{
		"not json":        `{`,
		"empty code":      `{"code":""}`,
		"timeout too big": `{"code":"p 1","timeout":31}`,
		"other context":   `{"code":"p 1","context":"python"}`,
		"huge code":       `{"code":"` + strings.Repeat("x", maxCodeBytes+1) + `"}`,
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			if rec := post(newHandler(&fakeRunner{}, Config{}), body); rec.Code != http.StatusBadRequest {
				t.Errorf("status = %d, want 400", rec.Code)
			}
		})
	}
}

func TestEvalRequiresTokenWhenConfigured(t *testing.T) {
	h := newHandler(&fakeRunner{}, Config{Token: "secret"})

	if rec := post(h, `{"code":"p 1"}`); rec.Code != http.StatusUnauthorized {
		t.Errorf("without token: status = %d, want 401", rec.Code)
	}
	if rec := post(h, `{"code":"p 1"}`, "Authorization", "Bearer wrong"); rec.Code != http.StatusUnauthorized {
		t.Errorf("wrong token: status = %d, want 401", rec.Code)
	}
	if rec := post(h, `{"code":"p 1"}`, "Authorization", "Bearer secret"); rec.Code != http.StatusOK {
		t.Errorf("right token: status = %d, want 200", rec.Code)
	}
}

func TestEvalRefusesWhenBusy(t *testing.T) {
	runner := &fakeRunner{block: make(chan struct{})}
	h := newHandler(runner, Config{})

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
