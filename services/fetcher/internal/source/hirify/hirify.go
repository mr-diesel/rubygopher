// Package hirify reads the JSON API behind hirify.me, an aggregator of mostly
// remote and relocation postings.
package hirify

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"rubygopher/fetcher/internal/posting"
	"rubygopher/fetcher/internal/source"
)

type Source struct {
	BaseURL     string
	SiteURL     string
	Client      *http.Client
	Pages       int
	RemoteTypes []string // hirify's remote_type filter, e.g. russia, europe, global; empty means everything
}

func New(remoteTypes []string) *Source {
	return &Source{BaseURL: "https://api.hirify.me", SiteURL: "https://hirify.me", Client: source.NewHTTPClient(), Pages: 5, RemoteTypes: remoteTypes}
}

func (s *Source) Name() string { return "hirify" }

type response struct {
	Data     []item `json:"data"`
	LastPage int    `json:"last_page"`
}

type item struct {
	ID           int      `json:"id"`
	Slug         string   `json:"slug"`
	Title        string   `json:"title"`
	MainStack    []string `json:"main_stack"`
	CompanyTitle *string  `json:"company_title"`
	LinkedIn     *string  `json:"linkedin"`
	WorkFormat   []string `json:"work_format"`
	Regions      []struct {
		NameEn string `json:"name_en"`
	} `json:"regions"`
	Salary *struct {
		Min      int    `json:"min"`
		Max      int    `json:"max"`
		Currency string `json:"currency"`
		Period   string `json:"salary_period"`
	} `json:"salary"`
	Tldr      string `json:"tldr"`
	CreatedAt string `json:"created_at"`
}

func (s *Source) Fetch(ctx context.Context, query string) ([]posting.Posting, error) {
	var all []posting.Posting
	for page := 1; page <= s.Pages; page++ {
		params := url.Values{"search": {query}, "page": {strconv.Itoa(page)}}
		for _, rt := range s.RemoteTypes {
			params.Add("remote_type[]", rt)
		}
		body, err := source.Get(ctx, s.Client, s.BaseURL+"/api/vacancies?"+params.Encode(), map[string]string{"Accept": "application/json"})
		if err != nil {
			return all, err
		}
		var resp response
		if err := json.Unmarshal(body, &resp); err != nil {
			return all, fmt.Errorf("hirify: decode: %w", err)
		}
		for _, it := range resp.Data {
			if source.Relevant(query, append([]string{it.Title}, it.MainStack...)...) {
				all = append(all, s.convert(it, query))
			}
		}
		if page >= resp.LastPage {
			break
		}
	}
	return all, nil
}

func (s *Source) convert(it item, query string) posting.Posting {
	p := posting.Posting{
		Source:      "hirify",
		ExternalID:  strconv.Itoa(it.ID),
		URL:         s.SiteURL + "/jobs/" + it.Slug,
		Title:       it.Title,
		Company:     posting.Company{Name: companyName(it)},
		Language:    source.LanguageFor(query),
		WorkMode:    workMode(it.WorkFormat),
		Description: it.Tldr,
		Raw:         it,
	}
	if len(it.Regions) > 0 {
		p.Location = it.Regions[0].NameEn
	}
	if it.Salary != nil {
		p.SalaryMin, p.SalaryMax, p.Currency = it.Salary.Min, it.Salary.Max, it.Salary.Currency
		if it.Salary.Period == "year" {
			p.SalaryMin, p.SalaryMax = p.SalaryMin/12, p.SalaryMax/12
		}
	}
	if t, err := time.Parse(time.RFC3339Nano, it.CreatedAt); err == nil {
		p.PublishedAt = &t
	}
	return p
}

// hirify hides some employers behind a placeholder; the LinkedIn company slug is
// the next best name, and "Unknown" keeps the contract (company name is required).
func companyName(it item) string {
	if it.CompanyTitle != nil && *it.CompanyTitle != "" && !strings.HasPrefix(*it.CompanyTitle, "%") {
		return *it.CompanyTitle
	}
	if it.LinkedIn != nil {
		if parts := strings.Split(strings.Trim(*it.LinkedIn, "/"), "/company/"); len(parts) == 2 {
			return strings.Split(parts[1], "/")[0]
		}
	}
	return "Unknown (hirify)"
}

func workMode(formats []string) string {
	for _, f := range formats {
		switch f {
		case "remote", "hybrid", "onsite":
			return f
		}
	}
	return ""
}
