// sandboxd runs untrusted Ruby snippets for the RubyGopher console inside a
// locked-down container. What the snippet printed is decided by the Rails
// evaluator.rb copied into the image, so every runner reports the same shape.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"rubygopher/sandboxd/internal/api"
	"rubygopher/sandboxd/internal/sandbox"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	runner := &sandbox.Runner{
		Ruby:      envOr("SANDBOX_RUBY", "ruby"),
		Evaluator: envOr("SANDBOX_EVALUATOR", "/opt/sandbox/evaluator.rb"),
		MaxOutput: 1 << 20,
	}

	server := &http.Server{
		Addr:              envOr("SANDBOX_ADDR", ":8080"),
		Handler:           api.NewHandler(runner, logger, 4),
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	errs := make(chan error, 1)
	go func() { errs <- server.ListenAndServe() }()
	logger.Info("sandboxd listening", "addr", server.Addr)

	select {
	case err := <-errs:
		logger.Error("server stopped", "err", err)
		os.Exit(1)
	case <-ctx.Done():
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 35*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil && !errors.Is(err, http.ErrServerClosed) {
		logger.Error("shutdown failed", "err", err)
	}
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
