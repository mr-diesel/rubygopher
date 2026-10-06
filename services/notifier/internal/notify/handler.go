package notify

import (
	"context"
	"log/slog"
	"sync"

	"rubygopher/notifier/internal/event"
)

type Sender interface {
	SendMessage(ctx context.Context, chatID int64, text string) error
}

// LogSender stands in for Telegram when no bot token is configured (local dev).
type LogSender struct{ Logger *slog.Logger }

func (l LogSender) SendMessage(_ context.Context, chatID int64, text string) error {
	l.Logger.Info("would send", "chat_id", chatID, "text", text)
	return nil
}

// Handler delivers one tracker event. Delivery is at-least-once from Kafka, so a
// bounded set of recently seen event ids drops the duplicates a restart can replay.
type Handler struct {
	Sender Sender
	Logger *slog.Logger
	seen   seenSet
}

func (h *Handler) Handle(ctx context.Context, raw []byte) error {
	e, err := event.Parse(raw)
	if err != nil {
		h.Logger.Warn("unreadable event skipped", "err", err)
		return nil
	}
	if h.seen.add(e.ID) {
		h.Logger.Info("duplicate skipped", "event_id", e.ID)
		return nil
	}
	text := Format(e)
	if text == "" {
		return nil
	}
	if e.TelegramChatID == 0 {
		h.Logger.Info("no telegram chat, skipped", "event_id", e.ID, "user_id", e.UserID, "type", e.Type)
		return nil
	}
	if err := h.Sender.SendMessage(ctx, e.TelegramChatID, text); err != nil {
		h.seen.remove(e.ID)
		return err
	}
	h.Logger.Info("sent", "event_id", e.ID, "type", e.Type, "chat_id", e.TelegramChatID)
	return nil
}

const seenLimit = 10000

type seenSet struct {
	mu    sync.Mutex
	ids   map[int64]struct{}
	order []int64
}

// add reports whether the id was already present; the oldest ids fall off past the limit.
func (s *seenSet) add(id int64) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.ids == nil {
		s.ids = make(map[int64]struct{})
	}
	if _, ok := s.ids[id]; ok {
		return true
	}
	s.ids[id] = struct{}{}
	s.order = append(s.order, id)
	if len(s.order) > seenLimit {
		delete(s.ids, s.order[0])
		s.order = s.order[1:]
	}
	return false
}

func (s *seenSet) remove(id int64) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.ids, id)
}
