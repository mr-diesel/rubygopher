module Outbox
  # Transactional outbox: domain events are written in the same transaction as the
  # data they describe and relayed to Kafka afterwards, so a crash between the two
  # can only delay an event, never lose or invent one.
  class Event < ApplicationRecord
    self.table_name = "outbox_events"

    scope :unpublished, -> { where(published_at: nil).order(:id) }

    after_commit :schedule_publish, on: :create

    def self.record!(topic:, key:, type:, payload:)
      create!(topic: topic, key: key, event_type: type, payload: payload)
    end

    def message
      { topic: topic, key: key, payload: payload.merge("event_id" => id, "type" => event_type, "recorded_at" => created_at.utc.iso8601).to_json }
    end

    private

    def schedule_publish
      Outbox::Jobs::PublishJob.perform_later
    end
  end
end
