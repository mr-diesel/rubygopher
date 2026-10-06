package fetcher

import (
	"context"
	"errors"
	"log/slog"
	"sync"
	"testing"
	"time"

	"rubygopher/fetcher/internal/posting"
)

type fakeSource struct {
	name     string
	postings []posting.Posting
	err      error
}

func (s fakeSource) Name() string { return s.name }
func (s fakeSource) Fetch(_ context.Context, query string) ([]posting.Posting, error) {
	return s.postings, s.err
}

type fakeProducer struct {
	mu        sync.Mutex
	published []posting.Posting
	err       error
}

func (p *fakeProducer) Publish(_ context.Context, postings []posting.Posting) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.err != nil {
		return p.err
	}
	p.published = append(p.published, postings...)
	return nil
}
func (p *fakeProducer) Close() {}

func newFetcher(prod *fakeProducer, sources ...fakeSource) *Fetcher {
	f := &Fetcher{Queries: []string{"ruby", "go"}, Producer: prod, Logger: slog.New(slog.DiscardHandler), Timeout: time.Second}
	for _, s := range sources {
		f.Sources = append(f.Sources, s)
	}
	return f
}

func TestRunOncePublishesEverySourceAndQuery(t *testing.T) {
	prod := &fakeProducer{}
	f := newFetcher(prod,
		fakeSource{name: "a", postings: []posting.Posting{{Source: "a", ExternalID: "1"}}},
		fakeSource{name: "b", postings: []posting.Posting{{Source: "b", ExternalID: "1"}, {Source: "b", ExternalID: "2"}}},
	)

	if n := f.RunOnce(context.Background()); n != 6 || len(prod.published) != 6 {
		t.Errorf("published %d (reported %d), want 6: 2 queries × (1 + 2) postings", len(prod.published), n)
	}
}

func TestRunOnceKeepsGoingWhenOneSourceFails(t *testing.T) {
	prod := &fakeProducer{}
	f := newFetcher(prod,
		fakeSource{name: "down", err: errors.New("boom")},
		fakeSource{name: "up", postings: []posting.Posting{{Source: "up", ExternalID: "1"}}},
	)

	if n := f.RunOnce(context.Background()); n != 2 {
		t.Errorf("published %d, want 2", n)
	}
}

func TestRunOncePublishesPartialResultsOfAFailedSource(t *testing.T) {
	prod := &fakeProducer{}
	f := newFetcher(prod, fakeSource{name: "flaky", postings: []posting.Posting{{Source: "flaky", ExternalID: "1"}}, err: errors.New("page 2 timed out")})

	if n := f.RunOnce(context.Background()); n != 2 {
		t.Errorf("published %d, want the postings fetched before the error", n)
	}
}

func TestRunOnceSurvivesProducerErrors(t *testing.T) {
	prod := &fakeProducer{err: errors.New("kafka down")}
	f := newFetcher(prod, fakeSource{name: "a", postings: []posting.Posting{{Source: "a", ExternalID: "1"}}})

	if n := f.RunOnce(context.Background()); n != 0 {
		t.Errorf("published %d, want 0", n)
	}
}

func TestRunStopsOnCancel(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	f := newFetcher(&fakeProducer{}, fakeSource{name: "a"})
	done := make(chan struct{})
	go func() {
		f.Run(ctx, time.Hour)
		close(done)
	}()
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("Run did not stop after cancel")
	}
}
