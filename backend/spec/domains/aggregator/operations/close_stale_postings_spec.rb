require "rails_helper"

RSpec.describe Aggregator::Operations::CloseStalePostings do
  it "deactivates aggregated postings unseen for a week and leaves the rest" do
    stale = create(:vacancy_posting, source: :hh, last_seen_at: 8.days.ago)
    fresh = create(:vacancy_posting, source: :hh, last_seen_at: 2.days.ago)
    manual = create(:vacancy_posting, source: :manual, last_seen_at: 30.days.ago)

    expect(described_class.new.call.value!).to eq(1)
    expect(stale.reload).not_to be_active
    expect(fresh.reload).to be_active
    expect(manual.reload).to be_active
  end

  it "is idempotent" do
    create(:vacancy_posting, source: :hh, last_seen_at: 8.days.ago)
    described_class.new.call

    expect(described_class.new.call.value!).to eq(0)
  end
end
