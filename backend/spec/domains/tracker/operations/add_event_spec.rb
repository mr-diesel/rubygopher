require "rails_helper"

RSpec.describe Tracker::Operations::AddEvent do
  let(:user) { create(:user) }
  let(:application) { create(:job_application, user: user, status: :applied, last_activity_at: 3.days.ago) }

  def call(input)
    described_class.new.call(user, application.id, input)
  end

  it "moves the application to the new status" do
    result = call(event_type: "status_changed", status: "screening", comment: "HR call")

    expect(result.value!).to have_attributes(event_type: "status_changed", status: "screening", comment: "HR call")
    expect(application.reload).to be_screening
    expect(application.last_activity_at).to be_within(1.second).of(Time.current)
  end

  it "keeps the status on a note" do
    call(event_type: "note_added", comment: "asked about salary")

    expect(application.reload).to be_applied
  end

  it "schedules the next follow-up" do
    call(event_type: "follow_up_sent", next_follow_up_at: "2026-10-20T09:00:00Z")

    expect(application.reload.next_follow_up_at).to eq(Time.utc(2026, 10, 20, 9))
  end

  it "clears the follow-up when nil is given explicitly" do
    application.update!(next_follow_up_at: 1.day.from_now)

    call(event_type: "follow_up_sent", next_follow_up_at: nil)

    expect(application.reload.next_follow_up_at).to be_nil
  end

  it "requires a status for status_changed" do
    result = call(event_type: "status_changed")

    expect(result.failure).to eq([ :invalid, { status: [ "is required for status_changed" ] } ])
  end

  it "does not touch another user's application" do
    other = create(:job_application)

    result = described_class.new.call(user, other.id, event_type: "note_added")

    expect(result.failure).to eq([ :not_found ])
    expect(other.events).to be_empty
  end
end
