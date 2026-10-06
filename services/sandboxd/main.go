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
		Go:        envOr("SANDBOX_GO", "go"),
		Evaluator: envOr("SANDBOX_EVALUATOR", "/app/app/domains/playground/evaluator.rb"),
		RailsRoot: envOr("SANDBOX_RAILS_ROOT", "/app"),
		MaxOutput: 1 << 20,
	}
	go warmGoCache(runner, logger)

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

// The build cache lives in tmpfs and starts empty: compiling a hello world once
// makes the first real Go snippet fast instead of a ten-second stdlib build.
func warmGoCache(runner *sandbox.Runner, logger *slog.Logger) {
	const hello = "package main\n\nimport (\n\t\"encoding/json\"\n\t\"fmt\"\n\t\"os\"\n\t\"sort\"\n\t\"strings\"\n\t\"sync\"\n\t\"time\"\n)\n\nfunc main() {\n\t_ = []any{json.Marshal, fmt.Println, os.Exit, sort.Ints, strings.Fields, new(sync.WaitGroup), time.Now}\n}\n"
	started := time.Now()
	result, err := runner.Run(context.Background(), hello, "go", 10*time.Second)
	if err != nil || result.Error != nil {
		logger.Warn("go cache warm-up failed", "err", err, "result", result.Error)
		return
	}
	logger.Info("go cache warmed", "took", time.Since(started).String())
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
