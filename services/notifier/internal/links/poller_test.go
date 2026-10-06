package links

import (
	"context"
	"encoding/json"
	"log/slog"
	"testing"

	"rubygopher/notifier/internal/telegram"
)

type fakeTelegram struct {
	updates []telegram.Update
	sent    []string
}

func (f *fakeTelegram) GetUpdates(context.Context, int64, int) ([]telegram.Update, error) {
	return f.updates, nil
}
func (f *fakeTelegram) SendMessage(_ context.Context, _ int64, text string) error {
	f.sent = append(f.sent, text)
	return nil
}

type fakeProducer struct{ values [][]byte }

func (f *fakeProducer) Produce(_ context.Context, _ string, value []byte) error {
	f.values = append(f.values, value)
	return nil
}

func update(text string) telegram.Update {
	var u telegram.Update
	json.Unmarshal([]byte(`{"update_id":1,"message":{"text":"`+text+`","chat":{"id":9,"username":"bob"}}}`), &u)
	return u
}

func TestParseStart(t *testing.T) {
	if code, ok := ParseStart("/start abc123"); !ok || code != "abc123" {
		t.Errorf("got %q %v", code, ok)
	}
	for _, text := range []string{"/start", "hello", "/start a b"} {
		if _, ok := ParseStart(text); ok {
			t.Errorf("%q should not parse", text)
		}
	}
}

func TestStartCommandIsPublishedAndAcknowledged(t *testing.T) {
	tg := &fakeTelegram{}
	prod := &fakeProducer{}
	p := &Poller{Telegram: tg, Producer: prod, Logger: slog.New(slog.DiscardHandler)}

	p.handle(context.Background(), update("/start abc123"))

	var link Link
	json.Unmarshal(prod.values[0], &link)
	if link.Code != "abc123" || link.ChatID != 9 || link.Username != "bob" {
		t.Errorf("link = %+v", link)
	}
	if len(tg.sent) != 1 {
		t.Errorf("the chat should get an acknowledgement, got %q", tg.sent)
	}
}

func TestOtherMessagesGetAHint(t *testing.T) {
	tg := &fakeTelegram{}
	prod := &fakeProducer{}
	p := &Poller{Telegram: tg, Producer: prod, Logger: slog.New(slog.DiscardHandler)}

	p.handle(context.Background(), update("hi"))

	if len(prod.values) != 0 || len(tg.sent) != 1 {
		t.Errorf("published=%d sent=%d", len(prod.values), len(tg.sent))
	}
}
