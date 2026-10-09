// Package notify turns tracker events into Telegram messages.
package notify

import (
	"fmt"
	"html"
	"strings"

	"rubygopher/notifier/internal/event"
)

// Format returns the message for an event, or "" when nothing should be sent.
func Format(e event.Event) string {
	company, vacancy := html.EscapeString(e.Company), html.EscapeString(e.Vacancy)
	switch e.Type {
	case "application.recorded":
		return fmt.Sprintf("📨 Отклик записан: <b>%s</b> — %s", company, vacancy)
	case "application.event_added":
		return applicationEvent(e, company, vacancy)
	case "application.follow_up_due":
		msg := fmt.Sprintf("⏰ Пора напомнить о себе: <b>%s</b> — %s", company, vacancy)
		if e.NextFollowUpAt != "" {
			msg += "\nFollow-up был запланирован на " + e.NextFollowUpAt
		}
		return msg
	case "outreach.recorded":
		return fmt.Sprintf("✉️ Письмо отправлено: <b>%s</b>", company)
	case "outreach.status_changed":
		if e.Event == nil {
			return ""
		}
		return fmt.Sprintf("✉️ <b>%s</b>: %s%s", company, status(e.Event.Status), comment(e.Event.Comment))
	case "user.telegram_linked":
		return "✅ Telegram подключён. Сюда будут приходить события трекера."
	}
	return ""
}

func applicationEvent(e event.Event, company, vacancy string) string {
	if e.Event == nil {
		return ""
	}
	switch e.Event.Type {
	case "status_changed":
		return fmt.Sprintf("🔁 <b>%s</b> — %s: %s%s", company, vacancy, status(e.Event.Status), comment(e.Event.Comment))
	case "note_added":
		return fmt.Sprintf("📝 <b>%s</b> — %s%s", company, vacancy, comment(e.Event.Comment))
	case "interview_scheduled":
		return fmt.Sprintf("📅 Интервью: <b>%s</b> — %s%s", company, vacancy, comment(e.Event.Comment))
	case "follow_up_sent":
		msg := fmt.Sprintf("📬 Follow-up отправлен: <b>%s</b> — %s", company, vacancy)
		if e.NextFollowUpAt != "" {
			msg += "\nСледующий: " + e.NextFollowUpAt
		}
		return msg
	}
	return ""
}

var statusNames = map[string]string{
	"applied": "откликнулся", "viewed": "просмотрено", "screening": "скрининг", "tech_interview": "техническое интервью",
	"offer": "оффер 🎉", "rejected": "отказ", "no_response": "без ответа", "talent_pool": "кадровый резерв", "interview": "интервью",
}

func status(code string) string {
	if name, ok := statusNames[code]; ok {
		return name
	}
	return strings.ReplaceAll(code, "_", " ")
}

func comment(text string) string {
	if strings.TrimSpace(text) == "" {
		return ""
	}
	return "\n" + html.EscapeString(text)
}
