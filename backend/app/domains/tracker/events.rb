module Tracker
  # Every tracker write leaves a domain event in the outbox, keyed by user so a
  # consumer sees one user's history in order.
  module Events
    TOPIC = "tracker.events".freeze

    def self.application_recorded(application)
      record("application.recorded", application.user_id, application_payload(application))
    end

    def self.application_event_added(application, event)
      record("application.event_added", application.user_id,
             application_payload(application).merge("event" => event.slice(:id, :event_type, :status, :comment, :occurred_at)))
    end

    def self.outreach_recorded(outreach)
      record("outreach.recorded", outreach.user_id, outreach_payload(outreach))
    end

    def self.outreach_status_changed(outreach, event)
      record("outreach.status_changed", outreach.user_id,
             outreach_payload(outreach).merge("event" => event.slice(:id, :status, :comment, :changed_at)))
    end

    def self.record(type, user_id, payload)
      Outbox::Event.record!(topic: TOPIC, key: "user:#{user_id}", type: type, payload: payload.merge("user_id" => user_id))
    end

    def self.application_payload(application)
      {
        "application_id" => application.id,
        "status" => application.status,
        "company" => application.company.name,
        "vacancy" => application.vacancy.title,
        "next_follow_up_at" => application.next_follow_up_at
      }
    end

    def self.outreach_payload(outreach)
      { "outreach_id" => outreach.id, "status" => outreach.status, "company" => outreach.company.name }
    end
  end
end
