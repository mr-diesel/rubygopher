FactoryBot.define do
  factory :outbox_event, class: "Outbox::Event" do
    topic { "tracker.events" }
    key { "user:1" }
    event_type { "application.recorded" }
    payload { { "application_id" => 1 } }
  end
end
