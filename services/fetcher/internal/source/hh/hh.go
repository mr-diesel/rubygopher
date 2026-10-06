// Package hh reads the public hh.ru API. Written against the documented response
// shape; hh.ru is geo-blocked outside Russia and may require an app token (HH_TOKEN).
package hh

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"rubygopher/fetcher/internal/posting"
	"rubygopher/fetcher/internal/source"
)

type Source struct {
	BaseURL string
	Token   string
	Client  *http.Client
	Pages   int
}

func New(token string) *Source {
	return &Source{BaseURL: "https://api.hh.ru", Token: token, Client: source.NewHTTPClient(), Pages: 2}
}

func (s *Source) Name() string { return "hh" }

type response struct {
	Items []item `json:"items"`
	Pages int    `json:"pages"`
}

type item struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	AlternateURL string `json:"alternate_url"`
	Employer     struct {
		ID           string `json:"id"`
		Name         string `json:"name"`
		AlternateURL string `json:"alternate_url"`
	} `json:"employer"`
	Area struct {
		Name string `json:"name"`
	} `json:"area"`
	Salary *struct {
		From     int    `json:"from"`
		To       int    `json:"to"`
		Currency string `json:"currency"`
	} `json:"salary"`
	Schedule struct {
		ID string `json:"id"`
	} `json:"schedule"`
	PublishedAt string `json:"published_at"`
	Snippet     struct {
		Requirement    string `json:"requirement"`
		Responsibility string `json:"responsibility"`
	} `json:"snippet"`
}

func (s *Source) Fetch(ctx context.Context, query string) ([]posting.Posting, error) {
	var all []posting.Posting
	for page := 0; page < s.Pages; page++ {
		resp, err := s.search(ctx, query, page)
		if err != nil {
			return all, err
		}
		for _, it := range resp.Items {
			all = append(all, convert(it, query))
		}
		if page+1 >= resp.Pages {
			break
		}
	}
	return all, nil
}

func (s *Source) search(ctx context.Context, query string, page int) (*response, error) {
	params := url.Values{
		"text":         {query},
		"search_field": {"name"},
		"order_by":     {"publication_time"},
		"period":       {"7"},
		"per_page":     {"100"},
		"page":         {fmt.Sprint(page)},
	}
	headers := map[string]string{"Accept": "application/json"}
	if s.Token != "" {
		headers["Authorization"] = "Bearer " + s.Token
	}
	body, err := source.Get(ctx, s.Client, s.BaseURL+"/vacancies?"+params.Encode(), headers)
	if err != nil {
		return nil, err
	}
	var resp response
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, fmt.Errorf("hh: decode: %w", err)
	}
	return &resp, nil
}

func convert(it item, query string) posting.Posting {
	p := posting.Posting{
		Source:     "hh",
		ExternalID: it.ID,
		URL:        it.AlternateURL,
		Title:      it.Name,
		Company:    posting.Company{Name: it.Employer.Name, ExternalID: it.Employer.ID, Website: it.Employer.AlternateURL},
		Language:   source.LanguageFor(query),
		Location:   it.Area.Name,
		Raw:        it,
	}
	if it.Schedule.ID == "remote" {
		p.WorkMode = "remote"
	}
	if it.Salary != nil {
		p.SalaryMin, p.SalaryMax, p.Currency = it.Salary.From, it.Salary.To, currency(it.Salary.Currency)
	}
	if t, err := time.Parse("2006-01-02T15:04:05-0700", it.PublishedAt); err == nil {
		p.PublishedAt = &t
	}
	if it.Snippet.Requirement != "" || it.Snippet.Responsibility != "" {
		p.Description = it.Snippet.Responsibility + "\n" + it.Snippet.Requirement
	}
	return p
}

// hh.ru says RUR where everyone else says RUB.
func currency(code string) string {
	if code == "RUR" {
		return "RUB"
	}
	return code
}
