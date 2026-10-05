package api

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"time"

	"rubygopher/sandboxd/internal/sandbox"
)

const (
	maxCodeBytes   = 64 << 10
	defaultTimeout = 5
	maxTimeout     = 30
)

type Runner interface {
	Run(ctx context.Context, code string, timeout time.Duration) (sandbox.Result, error)
}

type evalRequest struct {
	Code    string `json:"code"`
	Context string `json:"context"`
	Timeout int    `json:"timeout"`
}

type evalResponse struct {
	sandbox.Result
	Context    string `json:"context"`
	DurationMS int64  `json:"duration_ms"`
}

type handler struct {
	runner Runner
	logger *slog.Logger
	slots  chan struct{}
}

// Beyond maxParallel concurrent snippets the handler answers 503 instead of
// queueing, so a burst cannot pile up processes behind the container limits.
func NewHandler(runner Runner, logger *slog.Logger, maxParallel int) http.Handler {
	h := &handler{runner: runner, logger: logger, slots: make(chan struct{}, maxParallel)}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	mux.HandleFunc("POST /eval", h.eval)
	return mux
}

func (h *handler) eval(w http.ResponseWriter, r *http.Request) {
	req, err := decode(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	select {
	case h.slots <- struct{}{}:
		defer func() { <-h.slots }()
	default:
		writeError(w, http.StatusServiceUnavailable, "sandbox is busy")
		return
	}

	started := time.Now()
	result, err := h.runner.Run(r.Context(), req.Code, time.Duration(req.Timeout)*time.Second)
	if err != nil {
		h.logger.Error("evaluation failed", "err", err)
		writeError(w, http.StatusInternalServerError, "sandbox failed to run the snippet")
		return
	}

	writeJSON(w, http.StatusOK, evalResponse{
		Result:     result,
		Context:    req.Context,
		DurationMS: time.Since(started).Milliseconds(),
	})
}

func decode(r *http.Request) (evalRequest, error) {
	var req evalRequest
	body := io.LimitReader(r.Body, maxCodeBytes+1024)
	if err := json.NewDecoder(body).Decode(&req); err != nil {
		return req, errors.New("body must be JSON: " + err.Error())
	}

	switch {
	case req.Code == "":
		return req, errors.New("code is required")
	case len(req.Code) > maxCodeBytes:
		return req, errors.New("code exceeds 64 KiB")
	case req.Context == "":
		req.Context = "ruby"
	case req.Context != "ruby":
		return req, errors.New("unsupported context: " + req.Context)
	}

	switch {
	case req.Timeout == 0:
		req.Timeout = defaultTimeout
	case req.Timeout < 1 || req.Timeout > maxTimeout:
		return req, errors.New("timeout must be between 1 and 30 seconds")
	}
	return req, nil
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
