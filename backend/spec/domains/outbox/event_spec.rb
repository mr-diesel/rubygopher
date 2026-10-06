require "rails_helper"

RSpec.describe Outbox::Event do
  it "schedules the relay once the row is committed" do
    expect { described_class.record!(topic: "tracker.events", key: "user:1", type: "x", payload: {}) }
      .to have_enqueued_job(Outbox::Jobs::PublishJob)
  end

  it "builds a Kafka message with the envelope fields" do
    event = create(:outbox_event, payload: { "application_id" => 7 })
    message = event.message

    expect(message).to include(topic: "tracker.events", key: "user:1")
    expect(JSON.parse(message[:payload])).to include("application_id" => 7, "event_id" => event.id, "type" => "application.recorded", "recorded_at" => event.created_at.utc.iso8601)
  end
end
