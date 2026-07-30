FactoryBot.define do
  factory :job_application_event do
    job_application
    event_type { :note_added }
    comment { "Called back, waiting for a decision" }
    occurred_at { Time.current }
  end
end
