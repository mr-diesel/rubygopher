require "rails_helper"

RSpec.describe Tracker::Jobs::FollowUpRemindersJob do
  it "runs the reminder operation and is safe to repeat" do
    create(:job_application, user: create(:user), next_follow_up_at: 1.hour.ago)

    expect { described_class.perform_now }.to change(Outbox::Event, :count).by(1)
    expect { described_class.perform_now }.not_to change(Outbox::Event, :count)
  end
end
