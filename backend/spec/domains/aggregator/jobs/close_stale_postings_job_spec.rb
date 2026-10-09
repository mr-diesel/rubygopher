require "rails_helper"

RSpec.describe Aggregator::Jobs::CloseStalePostingsJob do
  it "closes stale postings" do
    posting = create(:vacancy_posting, source: :getmatch, last_seen_at: 10.days.ago)

    described_class.perform_now

    expect(posting.reload).not_to be_active
  end
end
