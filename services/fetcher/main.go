// fetcher collects Ruby and Go vacancies from job boards and publishes them to the
// vacancies.raw Kafka topic for the Rails aggregator to ingest.
package main

import (
	"context"
	"flag"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"rubygopher/fetcher/internal/fetcher"
	"rubygopher/fetcher/internal/producer"
	"rubygopher/fetcher/internal/source"
	"rubygopher/fetcher/internal/source/getmatch"
	"rubygopher/fetcher/internal/source/habr"
	"rubygopher/fetcher/internal/source/hh"
	"rubygopher/fetcher/internal/source/hirify"
)

func main() {
	once := flag.Bool("once", false, "run a single fetch and exit")
	flag.Parse()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	interval, err := time.ParseDuration(envOr("FETCH_INTERVAL", "15m"))
	if err != nil {
		logger.Error("bad FETCH_INTERVAL", "err", err)
		os.Exit(2)
	}

	kafka, err := producer.NewKafka(strings.Split(envOr("KAFKA_BROKERS", "localhost:29092"), ","), envOr("KAFKA_TOPIC", "vacancies.raw"))
	if err != nil {
		logger.Error("kafka client", "err", err)
		os.Exit(1)
	}
	defer kafka.Close()

	f := &fetcher.Fetcher{
		Sources:  enabledSources(strings.Split(envOr("FETCH_SOURCES", "hh,habr_career,hirify,getmatch"), ","), logger),
		Queries:  strings.Split(envOr("FETCH_QUERIES", "ruby,go"), ","),
		Producer: kafka,
		Logger:   logger,
		Timeout:  2 * time.Minute,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if *once {
		logger.Info("single run finished", "published", f.RunOnce(ctx))
		return
	}
	logger.Info("fetcher running", "interval", interval.String(), "queries", f.Queries)
	f.Run(ctx, interval)
}

// Boards are opt-in by name so a blocked or broken one can be switched off in compose.
func enabledSources(names []string, logger *slog.Logger) []source.Source {
	var sources []source.Source
	for _, name := range names {
		switch strings.TrimSpace(name) {
		case "hh":
			sources = append(sources, hh.New(os.Getenv("HH_TOKEN")))
		case "habr_career":
			sources = append(sources, habr.New())
		case "getmatch":
			sources = append(sources, getmatch.New())
		case "hirify":
			sources = append(sources, hirify.New(splitList(envOr("HIRIFY_REMOTE_TYPES", "russia"))))
		case "":
		default:
			logger.Warn("unknown source ignored", "name", name)
		}
	}
	return sources
}

// "a,b" → ["a","b"]; "" → nil, so an empty setting means "no filter".
func splitList(value string) []string {
	var items []string
	for _, item := range strings.Split(value, ",") {
		if item = strings.TrimSpace(item); item != "" {
			items = append(items, item)
		}
	}
	return items
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
