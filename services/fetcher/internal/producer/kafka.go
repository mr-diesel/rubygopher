// Package producer publishes postings to Kafka. The interface lets the fetcher be
// tested without a broker.
package producer

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/twmb/franz-go/pkg/kgo"

	"rubygopher/fetcher/internal/posting"
)

type Producer interface {
	Publish(ctx context.Context, postings []posting.Posting) error
	Close()
}

type Kafka struct {
	client *kgo.Client
	topic  string
}

func NewKafka(brokers []string, topic string) (*Kafka, error) {
	client, err := kgo.NewClient(
		kgo.SeedBrokers(brokers...),
		kgo.DefaultProduceTopic(topic),
		kgo.ProducerBatchCompression(kgo.SnappyCompression()),
		kgo.RequiredAcks(kgo.AllISRAcks()),
	)
	if err != nil {
		return nil, fmt.Errorf("kafka: %w", err)
	}
	return &Kafka{client: client, topic: topic}, nil
}

func (k *Kafka) Publish(ctx context.Context, postings []posting.Posting) error {
	records := make([]*kgo.Record, 0, len(postings))
	for _, p := range postings {
		value, err := json.Marshal(p)
		if err != nil {
			return fmt.Errorf("kafka: encode %s: %w", p.Key(), err)
		}
		records = append(records, &kgo.Record{Key: []byte(p.Key()), Value: value})
	}
	if len(records) == 0 {
		return nil
	}
	return k.client.ProduceSync(ctx, records...).FirstErr()
}

func (k *Kafka) Close() { k.client.Close() }
