module Outbox
  module Jobs
    # Drains unpublished events in id order. Safe to run concurrently and repeatedly:
    # rows are locked with SKIP LOCKED, and delivery is at-least-once (consumers
    # dedupe on event_id).
    class PublishJob < ApplicationJob
      queue_as :critical
      BATCH = 100

      def perform
        loop do
          published = Event.transaction do
            events = Event.unpublished.limit(BATCH).lock("FOR UPDATE SKIP LOCKED").to_a
            next 0 if events.empty?

            Karafka.producer.produce_many_sync(events.map(&:message))
            Event.where(id: events.map(&:id)).update_all(published_at: Time.current)
            events.size
          end
          break if published < BATCH
        end
      end
    end
  end
end
