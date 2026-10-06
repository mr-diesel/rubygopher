package habr

import (
	"os"
	"testing"
)

func TestSearchURLUsesSkillListings(t *testing.T) {
	s := New()
	if got := s.searchURL("ruby", 2); got != "https://career.habr.com/vacancies/skills/ruby?page=2&sort=date&type=all" {
		t.Errorf("ruby: %s", got)
	}
	if got := s.searchURL("golang", 1); got != "https://career.habr.com/vacancies/skills/golang?page=1&sort=date&type=all" {
		t.Errorf("go: %s", got)
	}
	if got := s.searchURL("rust", 1); got != "https://career.habr.com/vacancies?page=1&q=rust&sort=date&type=all" {
		t.Errorf("fallback: %s", got)
	}
}

func TestParseFixture(t *testing.T) {
	html, _ := os.ReadFile("testdata/search.html")

	postings, err := Parse(html, "https://career.habr.com", "rust")
	if err != nil {
		t.Fatal(err)
	}
	if len(postings) != 3 {
		t.Fatalf("got %d postings, want 3 (the fixture also holds 3 branded cards that must be skipped)", len(postings))
	}
	if ruby, _ := Parse(html, "https://career.habr.com", "ruby"); len(ruby) != 0 {
		t.Errorf("none of the fixture cards is about Ruby, got %d", len(ruby))
	}

	first := postings[0]
	if first.Source != "habr_career" || first.ExternalID != "1000129519" || first.URL != "https://career.habr.com/vacancies/1000129519" {
		t.Errorf("identity: %+v", first)
	}
	if first.Title != "Разработчик C# (.NET)" || first.Company.Name != "Action tech" || first.Company.ExternalID != "action-tech" {
		t.Errorf("title/company: %+v", first)
	}
	if first.WorkMode != "remote" || first.Language != "" || first.PublishedAt == nil {
		t.Errorf("attributes: %+v", first)
	}
}

func TestParseSalary(t *testing.T) {
	cases := []struct {
		text     string
		min, max int
		currency string
	}{
		{"от 75 000 ₽", 75000, 0, "RUB"},
		{"от 150 000 до 250 000 ₽", 150000, 250000, "RUB"},
		{"до 5 000 $", 0, 5000, "USD"},
		{"", 0, 0, ""},
	}
	for _, c := range cases {
		min, max, currency := parseSalary(c.text)
		if min != c.min || max != c.max || currency != c.currency {
			t.Errorf("%q: got %d-%d %s, want %d-%d %s", c.text, min, max, currency, c.min, c.max, c.currency)
		}
	}
}
