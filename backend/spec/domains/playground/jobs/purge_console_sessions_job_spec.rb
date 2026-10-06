require "rails_helper"

RSpec.describe Playground::Jobs::PurgeConsoleSessionsJob do
  it "runs the purge operation" do
    create(:console_session, updated_at: (ConsoleSession::TTL + 1.day).ago)

    expect { described_class.perform_now }.to change(ConsoleSession, :count).by(-1)
  end

  it "is safe to run twice" do
    create(:console_session, updated_at: (ConsoleSession::TTL + 1.day).ago)
    described_class.perform_now

    expect { described_class.perform_now }.not_to change(ConsoleSession, :count)
  end
end
