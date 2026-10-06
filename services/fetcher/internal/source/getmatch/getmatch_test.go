package getmatch

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestFetchConvertsActiveRelevantOffers(t *testing.T) {
	fixture, _ := os.ReadFile("testdata/offers.json")
	var gotQuery string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotQuery = r.URL.RawQuery
		w.Write(fixture)
	}))
	defer server.Close()

	s := New()
	s.BaseURL = server.URL
	postings, err := s.Fetch(context.Background(), "ruby")
	if err != nil {
		t.Fatal(err)
	}
	if gotQuery != "limit=20&offset=0&sp=ruby" {
		t.Errorf("query = %q", gotQuery)
	}
	if len(postings) != 1 {
		t.Fatalf("got %d postings, want 1 (the inactive offer is skipped)", len(postings))
	}

	p := postings[0]
	if p.Source != "getmatch" || p.ExternalID != "36425" || p.URL != server.URL+"/vacancies/36425-senior-software-engineer-ruby" {
		t.Errorf("identity: %+v", p)
	}
	if p.Company.Name != "Компания скрыта (Сфера развлечений)" || p.Company.ExternalID != "" {
		t.Errorf("company: %+v", p.Company)
	}
	if p.WorkMode != "remote" || p.Location != "Европа" || p.SalaryMin != 5500 || p.SalaryMax != 7000 || p.Currency != "EUR" || p.Language != "ruby" {
		t.Errorf("attributes: %+v", p)
	}
	if p.PublishedAt == nil || p.PublishedAt.UTC().Format("2006-01-02T15:04") != "2026-09-23T08:10" {
		t.Errorf("published_at should be read as Moscow time: %v", p.PublishedAt)
	}
}

func TestFetchMapsGoToTheGolangSpecialization(t *testing.T) {
	var gotQuery string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotQuery = r.URL.Query().Get("sp")
		w.Write([]byte(`{"meta":{"total":0,"offset":0,"limit":20},"offers":[]}`))
	}))
	defer server.Close()

	s := New()
	s.BaseURL = server.URL
	if _, err := s.Fetch(context.Background(), "go"); err != nil || gotQuery != "golang" {
		t.Errorf("sp=%q err=%v", gotQuery, err)
	}
}
