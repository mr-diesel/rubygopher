package notify

import (
	"context"
	"errors"
	"log/slog"
	"testing"
)

type fakeSender struct {
	sent []string
	err  error
}

func (f *fakeSender) SendMessage(_ context.Context, chatID int64, text string) error {
	if f.err != nil {
		return f.err
	}
	f.sent = append(f.sent, text)
	return nil
}

const recorded = `{"event_id":1,"type":"application.recorded","user_id":5,"telegram_chat_id":42,"company":"Acme","vacancy":"Dev"}`

func newHandler(s Sender) *Handler {
	return &Handler{Sender: s, Logger: slog.New(slog.DiscardHandler)}
}

func TestHandleSendsFormattedMessageOnce(t *testing.T) {
	sender := &fakeSender{}
	h := newHandler(sender)

	for i := 0; i < 2; i++ {
		if err := h.Handle(context.Background(), []byte(recorded)); err != nil {
			t.Fatal(err)
		}
	}
	if len(sender.sent) != 1 || sender.sent[0] != "📨 Отклик записан: <b>Acme</b> — Dev" {
		t.Errorf("sent = %q", sender.sent)
	}
}

func TestHandleSkipsUsersWithoutTelegram(t *testing.T) {
	sender := &fakeSender{}
	h := newHandler(sender)

	h.Handle(context.Background(), []byte(`{"event_id":2,"type":"application.recorded","user_id":5,"company":"Acme"}`))
	if len(sender.sent) != 0 {
		t.Errorf("should not send without a chat id")
	}
}

func TestHandleRetriesAfterSendFailure(t *testing.T) {
	sender := &fakeSender{err: errors.New("telegram down")}
	h := newHandler(sender)

	if err := h.Handle(context.Background(), []byte(recorded)); err == nil {
		t.Fatal("expected the send error to propagate")
	}
	sender.err = nil
	if err := h.Handle(context.Background(), []byte(recorded)); err != nil || len(sender.sent) != 1 {
		t.Errorf("a failed event must not be remembered as seen: sent=%d err=%v", len(sender.sent), err)
	}
}

func TestHandleIgnoresGarbage(t *testing.T) {
	if err := newHandler(&fakeSender{}).Handle(context.Background(), []byte("not json")); err != nil {
		t.Errorf("garbage must be skipped, not retried: %v", err)
	}
}
