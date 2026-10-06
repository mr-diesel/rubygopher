package source

import "testing"

func TestRelevant(t *testing.T) {
	cases := []struct {
		query, text string
		want        bool
	}{
		{"go", "Go Developer", true},
		{"go", "Senior Golang Engineer", true},
		{"go", "Django developer", false},
		{"go", "QA Automation (Java/Kotlin)", false},
		{"ruby", "Ruby on Rails developer", true},
		{"ruby", "Backend (RoR)", true},
		{"ruby", "Python Developer", false},
		{"rust", "anything", true},
	}
	for _, c := range cases {
		if got := Relevant(c.query, c.text); got != c.want {
			t.Errorf("Relevant(%q, %q) = %v, want %v", c.query, c.text, got, c.want)
		}
	}
}
