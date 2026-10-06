// Package kafka wraps franz-go for the notifier: a consumer group over
// tracker.events and a producer for telegram.links.
package kafka

import (
	"context"
	"fmt"

	"github.com/twmb/franz-go/pkg/kgo"
)

type Client struct {
	client *kgo.Client
}

func New(brokers []string, group, consumeTopic string) (*Client, error) {
	client, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.ConsumerGroup(group),
		kgo.ConsumeTopics(consumeTopic),
		kgo.DisableAutoCommit(),
		kgo.RequiredAcks(kgo.AllISRAcks()),
	)
	if err != nil {
		return nil, fmt.Errorf("kafka: %w", err)
	}
	return &Client{client: client}, nil
}

// Consume hands every record to handle and commits only after the whole batch
// succeeded; a failing record stops the batch so it is redelivered.
func (c *Client) Consume(ctx context.Context, handle func(context.Context, []byte) error) error {
	for {
		fetches := c.client.PollFetches(ctx)
		if ctx.Err() != nil {
			return nil
		}
		if errs := fetches.Errors(); len(errs) > 0 {
			return fmt.Errorf("kafka: fetch: %v", errs[0].Err)
		}
		var failed error
		fetches.EachRecord(func(r *kgo.Record) {
			if failed != nil {
				return
			}
			failed = handle(ctx, r.Value)
		})
		if failed != nil {
			return failed
		}
		if err := c.client.CommitUncommittedOffsets(ctx); err != nil {
			return fmt.Errorf("kafka: commit: %w", err)
		}
	}
}

func (c *Client) ProduceTo(topic string) *Producer { return &Producer{client: c.client, topic: topic} }

type Producer struct {
	client *kgo.Client
	topic  string
}

func (p *Producer) Produce(ctx context.Context, key string, value []byte) error {
	return p.client.ProduceSync(ctx, &kgo.Record{Topic: p.topic, Key: []byte(key), Value: value}).FirstErr()
}

func (c *Client) Close() { c.client.Close() }
