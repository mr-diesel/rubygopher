// Package getmatch reads the JSON API behind getmatch.ru's vacancy list.
package getmatch

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
	BaseURL string
	Path    string
	Client  *http.Client
	Limit   int
	Pages   int
}

func New() *Source {
	return &Source{BaseURL: "https://getmatch.ru", Path: "/api/offers", Client: source.NewHTTPClient(), Limit: 20, Pages: 5}
}

func (s *Source) Name() string { return "getmatch" }

// getmatch filters by specialization, not by free text.
var specializations = map[string]string{"ruby": "ruby", "go": "golang"}

type response struct {
	Meta struct {
		Total  int `json:"total"`
		Offset int `json:"offset"`
		Limit  int `json:"limit"`
	} `json:"meta"`
	Offers []offer `json:"offers"`
}

type offer struct {
	ID          int    `json:"id"`
	Position    string `json:"position"`
	IsActive    bool   `json:"is_active"`
	OfferType   string `json:"offer_type"`
	URL         string `json:"url"`
	PublishedAt string `json:"published_at"`
	SalaryFrom  *int   `json:"salary_display_from"`
	SalaryTo    *int   `json:"salary_display_to"`
	Currency    string `json:"salary_currency"`
	Description string `json:"offer_description"`
	Skills      []struct {
		Name string `json:"name"`
	} `json:"skills_objects"`
	Locations []struct {
		Label  string `json:"label"`
		Format string `json:"format"`
	} `json:"location_items"`
	Company struct {
		ID   *int   `json:"id"`
		Name string `json:"name"`
		URL  string `json:"url"`
	} `json:"company"`
}

func (s *Source) Fetch(ctx context.Context, query string) ([]posting.Posting, error) {
	var all []posting.Posting
	for page := 0; page < s.Pages; page++ {
		offset := page * s.Limit
		params := url.Values{"sp": {specialization(query)}, "offset": {strconv.Itoa(offset)}, "limit": {strconv.Itoa(s.Limit)}}
		body, err := source.Get(ctx, s.Client, s.BaseURL+s.Path+"?"+params.Encode(), map[string]string{"Accept": "application/json"})
		if err != nil {
			return all, err
		}
		var resp response
		if err := json.Unmarshal(body, &resp); err != nil {
			return all, fmt.Errorf("getmatch: decode: %w", err)
		}
		for _, o := range resp.Offers {
			if p, ok := s.convert(o, query); ok {
				all = append(all, p)
			}
		}
		if offset+len(resp.Offers) >= resp.Meta.Total || len(resp.Offers) == 0 {
			break
		}
	}
	return all, nil
}

func specialization(query string) string {
	if sp, ok := specializations[source.LanguageFor(query)]; ok {
		return sp
	}
	return query
}

func (s *Source) convert(o offer, query string) (posting.Posting, bool) {
	skills := make([]string, 0, len(o.Skills))
	for _, sk := range o.Skills {
		skills = append(skills, sk.Name)
	}
	if !o.IsActive || (o.OfferType != "" && o.OfferType != "vacancy") || !source.Relevant(query, append(skills, o.Position)...) {
		return posting.Posting{}, false
	}

	p := posting.Posting{
		Source:      "getmatch",
		ExternalID:  strconv.Itoa(o.ID),
		URL:         s.BaseURL + o.URL,
		Title:       o.Position,
		Company:     posting.Company{Name: strings.TrimSpace(o.Company.Name), Website: s.BaseURL + o.Company.URL},
		Language:    source.LanguageFor(query),
		Description: o.Description,
		Currency:    o.Currency,
		Raw:         o,
	}
	if o.Company.ID != nil {
		p.Company.ExternalID = strconv.Itoa(*o.Company.ID)
	}
	if o.SalaryFrom != nil {
		p.SalaryMin = *o.SalaryFrom
	}
	if o.SalaryTo != nil {
		p.SalaryMax = *o.SalaryTo
	}
	for _, loc := range o.Locations {
		if loc.Format == "remote" {
			p.WorkMode = "remote"
		} else if p.WorkMode == "" {
			p.WorkMode = map[string]string{"office": "onsite", "hybrid": "hybrid"}[loc.Format]
		}
		if p.Location == "" && loc.Format != "remote" {
			p.Location = loc.Label
		}
	}
	// No zone in the stamp; getmatch is a Russian service, so read it as Moscow time.
	if t, err := time.ParseInLocation("2006-01-02T15:04:05.999999", o.PublishedAt, moscow); err == nil {
		p.PublishedAt = &t
	}
	return p, true
}

var moscow = time.FixedZone("MSK", 3*60*60)
