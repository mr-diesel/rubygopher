// sandboxd runs untrusted Ruby snippets for the RubyGopher console inside a
// locked-down container. What the snippet printed is decided by the Rails
// evaluator.rb (the app is mounted read-only), so every runner reports the same shape.
package main

import (
	"context"
	"errors"
	"flag"
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
	check := flag.Bool("check", false, "probe the running server and exit (for the container healthcheck)")
	flag.Parse()
	addr := envOr("SANDBOX_ADDR", ":8080")
	if *check {
		os.Exit(healthcheck("http://127.0.0.1" + addr + "/healthz"))
	}

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	runner := &sandbox.Runner{
		Ruby:      envOr("SANDBOX_RUBY", "ruby"),
		Evaluator: envOr("SANDBOX_EVALUATOR", "/app/app/domains/playground/evaluator.rb"),
		RailsRoot: envOr("SANDBOX_RAILS_ROOT", "/app"),
		MaxOutput: 1 << 20,
	}

	server := &http.Server{
		Addr:              addr,
		Handler:           api.NewHandler(runner, logger, api.Config{MaxParallel: 4, Token: os.Getenv("SANDBOX_TOKEN")}),
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

func healthcheck(url string) int {
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(url)
	if err != nil || resp.StatusCode != http.StatusNoContent {
		return 1
	}
	resp.Body.Close()
	return 0
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
