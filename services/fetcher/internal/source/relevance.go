package source

import (
	"regexp"
	"strings"
)

// Board search is full-text and fuzzy ("go" matches almost anything), so adapters
// keep only postings whose title or stack names the language.
var keywords = map[string]*regexp.Regexp{
	"ruby": regexp.MustCompile(`(?i)\b(ruby|rails|ror)\b`),
	"go":   regexp.MustCompile(`(?i)\b(go|golang)\b`),
}

func Relevant(query string, texts ...string) bool {
	pattern, ok := keywords[LanguageFor(query)]
	if !ok {
		return true
	}
	return pattern.MatchString(strings.Join(texts, " "))
}
