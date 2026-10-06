# frozen_string_literal: true

require_relative "config/environment"

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "localhost:29092") }
    config.client_id = "rubygopher"
    config.consumer_persistence = !Rails.env.development?
  end

  routes.draw do
    # Raw job postings from the Go fetchers; consumed here into canonical vacancies.
    topic "vacancies.raw" do
      config(partitions: 3, replication_factor: 1)
      consumer Aggregator::Consumers::RawPostingsConsumer
      dead_letter_queue(topic: "vacancies.raw.dlq", max_retries: 3)
    end

    # Tracker domain events, published from the outbox; consumed by the Go notifier.
    topic "tracker.events" do
      config(partitions: 3, replication_factor: 1)
      active false
    end
  end
end
