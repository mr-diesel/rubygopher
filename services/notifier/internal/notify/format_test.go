package notify

import (
	"strings"
	"testing"

	"rubygopher/notifier/internal/event"
)

func TestFormat(t *testing.T) {
	cases := []struct {
		name string
		e    event.Event
		want string
	}{
		{"recorded", event.Event{Type: "application.recorded", Company: "Acme", Vacancy: "Ruby dev"}, "📨 Отклик записан: <b>Acme</b> — Ruby dev"},
		{"status", event.Event{Type: "application.event_added", Company: "Acme", Vacancy: "Ruby dev", Event: &event.Detail{Type: "status_changed", Status: "offer", Comment: "300k"}}, "🔁 <b>Acme</b> — Ruby dev: оффер 🎉\n300k"},
		{"note", event.Event{Type: "application.event_added", Company: "Acme", Vacancy: "Dev", Event: &event.Detail{Type: "note_added", Comment: "asked <b>HR</b>"}}, "📝 <b>Acme</b> — Dev\nasked &lt;b&gt;HR&lt;/b&gt;"},
		{"follow-up", event.Event{Type: "application.event_added", Company: "Acme", Vacancy: "Dev", NextFollowUpAt: "2026-10-20T09:00:00Z", Event: &event.Detail{Type: "follow_up_sent"}}, "📬 Follow-up отправлен: <b>Acme</b> — Dev\nСледующий: 2026-10-20T09:00:00Z"},
		{"outreach", event.Event{Type: "outreach.status_changed", Company: "Globex", Event: &event.Detail{Status: "interview"}}, "✉️ <b>Globex</b>: интервью"},
		{"linked", event.Event{Type: "user.telegram_linked"}, "✅ Telegram подключён"},
		{"unknown", event.Event{Type: "something.else"}, ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := Format(c.e); !strings.HasPrefix(got, c.want) {
				t.Errorf("got %q, want prefix %q", got, c.want)
			}
		})
	}
}
