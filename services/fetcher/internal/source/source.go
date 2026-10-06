// Package source defines what every job board adapter provides. Adapters are plain
// types satisfying the interface; the fetcher never knows which board it talks to.
package source

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"time"

	"rubygopher/fetcher/internal/posting"
)

type Source interface {
	Name() string
	Fetch(ctx context.Context, query string) ([]posting.Posting, error)
}

const UserAgent = "RubyGopher/1.0 (+https://github.com/mr-diesel/rubygopher)"

func NewHTTPClient() *http.Client {
	return &http.Client{Timeout: 15 * time.Second}
}

// Get fetches a URL with the project's User-Agent and returns the body, or an error
// carrying the status for anything but 200. Callers decide what a non-200 means.
func Get(ctx context.Context, client *http.Client, url string, headers map[string]string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", UserAgent)
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		return nil, &StatusError{URL: url, Status: resp.StatusCode}
	}
	return body, nil
}

type StatusError struct {
	URL    string
	Status int
}

func (e *StatusError) Error() string { return fmt.Sprintf("%s answered %d", e.URL, e.Status) }

// LanguageFor maps the search query to the vacancy language the tracker knows.
func LanguageFor(query string) string {
	switch query {
	case "go", "golang":
		return "go"
	case "ruby", "rails", "ruby on rails":
		return "ruby"
	}
	return ""
}
