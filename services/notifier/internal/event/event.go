// Package event is the tracker.events message as the Rails outbox publishes it.
package event

import "encoding/json"

type Event struct {
	ID             int64           `json:"event_id"`
	Type           string          `json:"type"`
	UserID         int64           `json:"user_id"`
	TelegramChatID int64           `json:"telegram_chat_id"`
	Company        string          `json:"company"`
	Vacancy        string          `json:"vacancy"`
	Status         string          `json:"status"`
	NextFollowUpAt string          `json:"next_follow_up_at"`
	Event          *Detail         `json:"event"`
	RecordedAt     string          `json:"recorded_at"`
	Raw            json.RawMessage `json:"-"`
}

// Detail is the application or outreach event nested in event_added / status_changed.
type Detail struct {
	Type    string `json:"event_type"`
	Status  string `json:"status"`
	Comment string `json:"comment"`
}

func Parse(data []byte) (Event, error) {
	var e Event
	err := json.Unmarshal(data, &e)
	e.Raw = data
	return e, err
}
