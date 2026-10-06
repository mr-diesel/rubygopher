// Package habr scrapes career.habr.com search pages: no public API exists.
package habr

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"

	"rubygopher/fetcher/internal/posting"
	"rubygopher/fetcher/internal/source"
)

type Source struct {
	BaseURL string
	Client  *http.Client
	Pages   int
}

func New() *Source {
	return &Source{BaseURL: "https://career.habr.com", Client: source.NewHTTPClient(), Pages: 3}
}

func (s *Source) Name() string { return "habr_career" }

// Habr has exact per-skill listings; the free-text search is fuzzy and mostly noise.
var skillPaths = map[string]string{"ruby": "/vacancies/skills/ruby", "go": "/vacancies/skills/golang"}

func (s *Source) searchURL(query string, page int) string {
	params := url.Values{"sort": {"date"}, "type": {"all"}, "page": {strconv.Itoa(page)}}
	if path, ok := skillPaths[source.LanguageFor(query)]; ok {
		return s.BaseURL + path + "?" + params.Encode()
	}
	params.Set("q", query)
	return s.BaseURL + "/vacancies?" + params.Encode()
}

func (s *Source) Fetch(ctx context.Context, query string) ([]posting.Posting, error) {
	var all []posting.Posting
	for page := 1; page <= s.Pages; page++ {
		body, err := source.Get(ctx, s.Client, s.searchURL(query, page), nil)
		if err != nil {
			return all, err
		}
		postings, err := Parse(body, s.BaseURL, query)
		if err != nil {
			return all, err
		}
		all = append(all, postings...)
		if len(postings) == 0 {
			break
		}
	}
	return all, nil
}

var idPattern = regexp.MustCompile(`/vacancies/(\d+)`)

// Parse turns a search results page into postings. Exported so the fixture test
// covers exactly what production runs.
func Parse(html []byte, baseURL, query string) ([]posting.Posting, error) {
	doc, err := goquery.NewDocumentFromReader(bytes.NewReader(html))
	if err != nil {
		return nil, fmt.Errorf("habr: parse: %w", err)
	}

	var postings []posting.Posting
	// Branded cards (vacancy-card--bp) are paid placements that ignore the query.
	doc.Find(".vacancy-card:not(.vacancy-card--bp)").Each(func(_ int, card *goquery.Selection) {
		link := card.Find(".vacancy-card__title-link").First()
		href, _ := link.Attr("href")
		match := idPattern.FindStringSubmatch(href)
		if match == nil {
			return
		}
		company := card.Find(".vacancy-card__company a").First()
		companyHref, _ := company.Attr("href")

		p := posting.Posting{
			Source:     "habr_career",
			ExternalID: match[1],
			URL:        baseURL + href,
			Title:      strings.TrimSpace(link.Text()),
			Company:    posting.Company{Name: strings.TrimSpace(company.Text()), ExternalID: strings.TrimPrefix(companyHref, "/companies/"), Website: baseURL + companyHref},
			Language:   source.LanguageFor(query),
		}
		card.Find(".vacancy-meta .chip-with-icon__text").Each(func(_ int, chip *goquery.Selection) {
			text := strings.TrimSpace(chip.Text())
			switch {
			case text == "Можно удалённо":
				p.WorkMode = "remote"
			case isGrade(text):
			default:
				p.Location = text
			}
		})
		p.SalaryMin, p.SalaryMax, p.Currency = parseSalary(card.Find(".vacancy-card__salary .basic-salary").Text())
		if stamp, ok := card.Find(".vacancy-card__date time").Attr("datetime"); ok {
			if t, err := time.Parse(time.RFC3339, stamp); err == nil {
				p.PublishedAt = &t
			}
		}
		skills := card.Find(".vacancy-card__skills .basic-chip__text").Map(func(_ int, s *goquery.Selection) string { return s.Text() })
		if source.Relevant(query, append(skills, p.Title)...) {
			postings = append(postings, p)
		}
	})
	return postings, nil
}

func isGrade(text string) bool {
	switch text {
	case "Intern", "Junior", "Middle", "Senior", "Lead":
		return true
	}
	return false
}

var amountPattern = regexp.MustCompile(`\d[\d\s ]*`)

// "от 75 000 ₽", "от 150 000 до 250 000 ₽", "до 5 000 $"
func parseSalary(text string) (min, max int, currency string) {
	text = strings.TrimSpace(text)
	if text == "" {
		return 0, 0, ""
	}
	amounts := amountPattern.FindAllString(text, -1)
	nums := make([]int, 0, len(amounts))
	for _, a := range amounts {
		n, err := strconv.Atoi(strings.NewReplacer(" ", "", " ", "").Replace(a))
		if err == nil {
			nums = append(nums, n)
		}
	}
	switch {
	case strings.Contains(text, "₽"):
		currency = "RUB"
	case strings.Contains(text, "$"):
		currency = "USD"
	case strings.Contains(text, "€"):
		currency = "EUR"
	}
	hasFrom, hasTo := strings.Contains(text, "от"), strings.Contains(text, "до")
	switch {
	case len(nums) >= 2:
		return nums[0], nums[1], currency
	case len(nums) == 1 && hasTo && !hasFrom:
		return 0, nums[0], currency
	case len(nums) == 1:
		return nums[0], 0, currency
	}
	return 0, 0, currency
}
