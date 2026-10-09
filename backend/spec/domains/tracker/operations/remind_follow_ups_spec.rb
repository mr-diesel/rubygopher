require "rails_helper"

RSpec.describe Tracker::Operations::RemindFollowUps do
  let(:user) { create(:user, telegram_chat_id: 7) }
  let(:now) { Time.current }

  it "emits one follow_up_due event per due application and remembers it" do
    due = create(:job_application, user: user, next_follow_up_at: 1.hour.ago)
    create(:job_application, user: user, next_follow_up_at: 1.day.from_now)
    create(:job_application, user: user, next_follow_up_at: 1.hour.ago, archived_at: now)

    expect(described_class.new.call(now: now).value!).to eq(1)

    event = Outbox::Event.sole
    expect(event.event_type).to eq("application.follow_up_due")
    expect(event.payload).to include("application_id" => due.id, "telegram_chat_id" => 7)
    expect(due.reload.follow_up_reminded_at).to be_within(1.second).of(now)
  end

  it "does not remind twice for the same date, but does for a new one" do
    application = create(:job_application, user: user, next_follow_up_at: 1.hour.ago)
    described_class.new.call(now: now)

    expect(described_class.new.call(now: now + 10.minutes).value!).to eq(0)

    application.update!(next_follow_up_at: now + 1.hour)
    expect(described_class.new.call(now: now + 2.hours).value!).to eq(1)
    expect(Outbox::Event.count).to eq(2)
  end
end
