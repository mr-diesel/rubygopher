package telegram

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestSendMessagePostsHTML(t *testing.T) {
	var got map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/botTOKEN/sendMessage" {
			t.Errorf("path = %s", r.URL.Path)
		}
		json.NewDecoder(r.Body).Decode(&got)
		w.Write([]byte(`{"ok":true,"result":{}}`))
	}))
	defer server.Close()

	c := New("TOKEN")
	c.BaseURL = server.URL
	if err := c.SendMessage(context.Background(), 42, "<b>hi</b>"); err != nil {
		t.Fatal(err)
	}
	if got["chat_id"] != float64(42) || got["text"] != "<b>hi</b>" || got["parse_mode"] != "HTML" {
		t.Errorf("payload = %v", got)
	}
}

func TestErrorsCarryTelegramDescription(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(400)
		w.Write([]byte(`{"ok":false,"description":"Bad Request: chat not found"}`))
	}))
	defer server.Close()

	c := New("TOKEN")
	c.BaseURL = server.URL
	err := c.SendMessage(context.Background(), 1, "x")
	if err == nil || err.Error() != "telegram sendMessage: Bad Request: chat not found (http 400)" {
		t.Errorf("err = %v", err)
	}
}

func TestGetUpdatesDecodesMessages(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte(`{"ok":true,"result":[{"update_id":7,"message":{"text":"/start abc","chat":{"id":5,"username":"bob"}}}]}`))
	}))
	defer server.Close()

	c := New("TOKEN")
	c.BaseURL = server.URL
	updates, err := c.GetUpdates(context.Background(), 0, 1)
	if err != nil || len(updates) != 1 || updates[0].Message.Text != "/start abc" || updates[0].Message.Chat.ID != 5 {
		t.Errorf("updates = %+v err = %v", updates, err)
	}
}
