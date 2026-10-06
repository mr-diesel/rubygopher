require "rails_helper"

RSpec.describe Tracker::Operations::ChangeOutreachStatus do
  let(:user) { create(:user) }
  let(:outreach) { create(:company_outreach, user: user) }

  it "records the new status with an event" do
    result = described_class.new.call(user, outreach.id, status: "interview", comment: "call on Monday")

    expect(result.value!).to have_attributes(status: "interview", comment: "call on Monday")
    expect(outreach.reload).to be_interview
  end

  it "rejects an unknown status" do
    result = described_class.new.call(user, outreach.id, status: "ghosted")

    expect(result.failure.first).to eq(:invalid)
    expect(outreach.events).to be_empty
  end

  it "does not touch another user's outreach" do
    other = create(:company_outreach)

    expect(described_class.new.call(user, other.id, status: "offer").failure).to eq([ :not_found ])
  end
end
