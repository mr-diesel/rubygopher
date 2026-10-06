package hirify

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestFetchConvertsItems(t *testing.T) {
	fixture, _ := os.ReadFile("testdata/search.json")
	var gotSearch string
	var gotRemote []string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotSearch = r.URL.Query().Get("search")
		gotRemote = r.URL.Query()["remote_type[]"]
		w.Write(fixture)
	}))
	defer server.Close()

	s := New([]string{"russia", "global"})
	s.BaseURL = server.URL
	s.Pages = 1
	postings, err := s.Fetch(context.Background(), "ruby")
	if err != nil {
		t.Fatal(err)
	}
	if gotSearch != "ruby" || len(postings) != 3 {
		t.Fatalf("search=%q postings=%d", gotSearch, len(postings))
	}
	if len(gotRemote) != 2 || gotRemote[0] != "russia" || gotRemote[1] != "global" {
		t.Errorf("remote_type[] = %v", gotRemote)
	}

	first := postings[0]
	if first.Source != "hirify" || first.ExternalID != "1212044" || first.URL != "https://hirify.me/jobs/1212044-senior-backend-engineer-ruby" {
		t.Errorf("identity: %+v", first)
	}
	if first.Company.Name != "gitlab-com" {
		t.Errorf("placeholder company should fall back to the LinkedIn slug, got %q", first.Company.Name)
	}
	if first.WorkMode != "remote" || first.Location != "Poland" || first.Language != "ruby" {
		t.Errorf("attributes: %+v", first)
	}
	if first.SalaryMin != 272000/12 || first.SalaryMax != 408000/12 || first.Currency != "PLN" {
		t.Errorf("yearly salary should be converted to monthly: %+v", first)
	}
	if second := postings[1]; second.Company.Name != "OpsLevel" || second.SalaryMin != 0 {
		t.Errorf("second: %+v", second)
	}
}
