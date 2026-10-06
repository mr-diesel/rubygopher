// Package fetcher runs every source for every query, concurrently, and publishes
// whatever came back. One board failing never stops the others; a replayed posting
// is harmless because the Rails consumer is idempotent.
package fetcher

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"rubygopher/fetcher/internal/posting"
	"rubygopher/fetcher/internal/producer"
	"rubygopher/fetcher/internal/source"
)

type Fetcher struct {
	Sources  []source.Source
	Queries  []string
	Producer producer.Producer
	Logger   *slog.Logger
	Timeout  time.Duration
}

type result struct {
	source   string
	query    string
	postings []posting.Posting
	err      error
}

// RunOnce fetches all sources and returns how many postings were published.
func (f *Fetcher) RunOnce(ctx context.Context) int {
	results := make(chan result)
	var wg sync.WaitGroup
	for _, src := range f.Sources {
		for _, query := range f.Queries {
			wg.Add(1)
			go func(src source.Source, query string) {
				defer wg.Done()
				fetchCtx, cancel := context.WithTimeout(ctx, f.Timeout)
				defer cancel()
				postings, err := src.Fetch(fetchCtx, query)
				results <- result{source: src.Name(), query: query, postings: postings, err: err}
			}(src, query)
		}
	}
	go func() {
		wg.Wait()
		close(results)
	}()

	published := 0
	for r := range results {
		if r.err != nil {
			f.Logger.Warn("fetch failed", "source", r.source, "query", r.query, "err", r.err, "partial", len(r.postings))
		}
		if len(r.postings) == 0 {
			continue
		}
		if err := f.Producer.Publish(ctx, r.postings); err != nil {
			f.Logger.Error("publish failed", "source", r.source, "query", r.query, "err", err)
			continue
		}
		published += len(r.postings)
		f.Logger.Info("published", "source", r.source, "query", r.query, "count", len(r.postings))
	}
	return published
}

// Run repeats RunOnce every interval until the context is cancelled.
func (f *Fetcher) Run(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		f.RunOnce(ctx)
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}
	}
}
