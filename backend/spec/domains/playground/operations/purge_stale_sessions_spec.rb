require "rails_helper"

RSpec.describe Playground::Operations::PurgeStaleSessions do
  it "deletes stale sessions and keeps active ones" do
    fresh = create(:console_session)
    create(:console_session, updated_at: (ConsoleSession::TTL + 1.day).ago)

    result = described_class.new.call

    expect(result).to be_success
    expect(result.value!).to eq(1)
    expect(ConsoleSession.all).to contain_exactly(fresh)
  end

  it "is a no-op when nothing is stale" do
    create(:console_session)

    expect { described_class.new.call }.not_to change(ConsoleSession, :count)
  end
end
