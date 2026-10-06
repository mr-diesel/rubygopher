// notifier delivers tracker events to Telegram and relays "/start <code>" from the
// bot back to Rails over Kafka.
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"rubygopher/notifier/internal/kafka"
	"rubygopher/notifier/internal/links"
	"rubygopher/notifier/internal/notify"
	"rubygopher/notifier/internal/telegram"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	broker, err := kafka.New(strings.Split(envOr("KAFKA_BROKERS", "localhost:29092"), ","), envOr("KAFKA_GROUP", "notifier"), envOr("EVENTS_TOPIC", "tracker.events"))
	if err != nil {
		logger.Error("kafka", "err", err)
		os.Exit(1)
	}
	defer broker.Close()

	token := os.Getenv("TELEGRAM_BOT_TOKEN")
	var sender notify.Sender = notify.LogSender{Logger: logger}
	if token != "" {
		bot := telegram.New(token)
		sender = bot
		poller := &links.Poller{Telegram: bot, Producer: broker.ProduceTo(envOr("LINKS_TOPIC", "telegram.links")), Logger: logger}
		go poller.Run(ctx)
		logger.Info("telegram bot polling for /start")
	} else {
		logger.Warn("TELEGRAM_BOT_TOKEN is empty: messages are logged, not sent")
	}

	handler := &notify.Handler{Sender: sender, Logger: logger}
	logger.Info("notifier consuming", "topic", envOr("EVENTS_TOPIC", "tracker.events"))
	for ctx.Err() == nil {
		if err := broker.Consume(ctx, handler.Handle); err != nil {
			logger.Error("consume loop failed, retrying", "err", err)
			time.Sleep(5 * time.Second)
		}
	}
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
