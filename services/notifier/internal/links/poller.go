// Package links watches the bot for "/start <code>" and hands the (code, chat)
// pair to Rails through Kafka, which owns the user ↔ chat mapping.
package links

import (
	"context"
	"encoding/json"
	"log/slog"
	"strings"
	"time"

	"rubygopher/notifier/internal/telegram"
)

type Producer interface {
	Produce(ctx context.Context, key string, value []byte) error
}

type Updates interface {
	GetUpdates(ctx context.Context, offset int64, timeout int) ([]telegram.Update, error)
	SendMessage(ctx context.Context, chatID int64, text string) error
}

type Poller struct {
	Telegram Updates
	Producer Producer
	Logger   *slog.Logger
	offset   int64
}

type Link struct {
	Code     string `json:"code"`
	ChatID   int64  `json:"chat_id"`
	Username string `json:"username"`
}

// ParseStart extracts the code from "/start <code>"; ok is false for anything else.
func ParseStart(text string) (string, bool) {
	fields := strings.Fields(text)
	if len(fields) != 2 || fields[0] != "/start" {
		return "", false
	}
	return fields[1], true
}

func (p *Poller) Run(ctx context.Context) {
	for ctx.Err() == nil {
		updates, err := p.Telegram.GetUpdates(ctx, p.offset, 30)
		if err != nil {
			if ctx.Err() == nil {
				p.Logger.Warn("getUpdates failed", "err", err)
				time.Sleep(5 * time.Second)
			}
			continue
		}
		for _, u := range updates {
			p.offset = u.ID + 1
			p.handle(ctx, u)
		}
	}
}

func (p *Poller) handle(ctx context.Context, u telegram.Update) {
	if u.Message == nil {
		return
	}
	code, ok := ParseStart(u.Message.Text)
	if !ok {
		_ = p.Telegram.SendMessage(ctx, u.Message.Chat.ID, "Откройте ссылку «Connect Telegram» в RubyGopher, чтобы привязать этот чат.")
		return
	}
	value, _ := json.Marshal(Link{Code: code, ChatID: u.Message.Chat.ID, Username: u.Message.Chat.Username})
	if err := p.Producer.Produce(ctx, code, value); err != nil {
		p.Logger.Error("could not publish link", "err", err)
		_ = p.Telegram.SendMessage(ctx, u.Message.Chat.ID, "Не получилось связать чат, попробуйте ещё раз через минуту.")
		return
	}
	p.Logger.Info("link requested", "chat_id", u.Message.Chat.ID)
	_ = p.Telegram.SendMessage(ctx, u.Message.Chat.ID, "Код принят, связываю чат с аккаунтом…")
}
