// Package posting is the message published to vacancies.raw. Field names are the
// contract with the Rails consumer (Aggregator::Contracts::IngestPostingContract).
package posting

import "time"

type Company struct {
	Name       string `json:"name"`
	ExternalID string `json:"external_id,omitempty"`
	Website    string `json:"website,omitempty"`
}

type Posting struct {
	Source      string     `json:"source"`
	ExternalID  string     `json:"external_id"`
	URL         string     `json:"url"`
	Title       string     `json:"title"`
	Company     Company    `json:"company"`
	Language    string     `json:"language,omitempty"`
	Location    string     `json:"location,omitempty"`
	WorkMode    string     `json:"work_mode,omitempty"`
	SalaryMin   int        `json:"salary_min,omitempty"`
	SalaryMax   int        `json:"salary_max,omitempty"`
	Currency    string     `json:"currency,omitempty"`
	Description string     `json:"description,omitempty"`
	PublishedAt *time.Time `json:"published_at,omitempty"`
	Raw         any        `json:"raw,omitempty"`
}

// Key is the Kafka partition key: the same posting always lands on the same partition.
func (p Posting) Key() string { return p.Source + ":" + p.ExternalID }
