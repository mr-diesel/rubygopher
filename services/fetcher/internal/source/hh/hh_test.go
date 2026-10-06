package hh

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestFetchConvertsSearchResults(t *testing.T) {
	fixture, _ := os.ReadFile("testdata/search.json")
	var gotAuth, gotQuery string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotQuery = r.URL.Query().Get("text")
		w.Write(fixture)
	}))
	defer server.Close()

	s := New("secret")
	s.BaseURL = server.URL
	postings, err := s.Fetch(context.Background(), "ruby")
	if err != nil {
		t.Fatal(err)
	}

	if gotAuth != "Bearer secret" || gotQuery != "ruby" {
		t.Errorf("request: auth=%q query=%q", gotAuth, gotQuery)
	}
	if len(postings) != 2 {
		t.Fatalf("got %d postings", len(postings))
	}
	first := postings[0]
	if first.Source != "hh" || first.ExternalID != "123456" || first.URL != "https://hh.ru/vacancy/123456" {
		t.Errorf("identity: %+v", first)
	}
	if first.Company.Name != "Acme" || first.Company.ExternalID != "9" || first.Location != "Москва" {
		t.Errorf("company/location: %+v", first)
	}
	if first.WorkMode != "remote" || first.SalaryMin != 300000 || first.SalaryMax != 450000 || first.Currency != "RUB" || first.Language != "ruby" {
		t.Errorf("attributes: %+v", first)
	}
	if first.PublishedAt == nil || first.PublishedAt.UTC().Format("2006-01-02T15:04") != "2026-10-05T09:30" {
		t.Errorf("published_at: %v", first.PublishedAt)
	}
	if second := postings[1]; second.SalaryMin != 0 || second.WorkMode != "" {
		t.Errorf("second posting should have no salary and no work mode: %+v", second)
	}
}

func TestFetchReportsHTTPErrors(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(403) }))
	defer server.Close()

	s := New("")
	s.BaseURL = server.URL
	if _, err := s.Fetch(context.Background(), "ruby"); err == nil {
		t.Fatal("expected an error")
	}
}
