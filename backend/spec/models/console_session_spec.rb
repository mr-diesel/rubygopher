require "rails_helper"

RSpec.describe ConsoleSession do
  it "accepts only known contexts" do
    expect(build(:console_session, context: "python")).not_to be_valid
    expect(build(:console_session, context: "go")).to be_valid
  end

  it "generates a unique token on create" do
    first, second = create_list(:console_session, 2)

    expect(first.token).to be_present
    expect(first.token).not_to eq(second.token)
  end

  it "keeps an explicitly given token" do
    expect(create(:console_session, token: "abc123").token).to eq("abc123")
  end

  describe "scopes" do
    let!(:fresh) { create(:console_session) }
    let!(:stale) { create(:console_session, updated_at: (described_class::TTL + 1.hour).ago) }

    it "separates active and stale sessions by the last update" do
      expect(described_class.active).to contain_exactly(fresh)
      expect(described_class.stale).to contain_exactly(stale)
    end
  end

  describe "#apply!" do
    let(:session) { create(:console_session) }

    it "stores the latest code and context" do
      session.apply!(code: "p 2", context: "rails", by: 7)

      expect(session.reload).to have_attributes(code: "p 2", context: "rails")
    end

    it "broadcasts the new state to the session" do
      expect { session.apply!(code: "p 2", context: "rails", by: 7) }
        .to have_broadcasted_to(session).from_channel(ConsoleSession.channel)
        .with(hash_including("type" => "state", "code" => "p 2", "by" => 7))
    end
  end

  describe "#record_run!" do
    let(:session) { create(:console_session) }

    it "stores the result with the runner's id and broadcasts it" do
      expect { session.record_run!({ "output" => "2\n", "error" => nil }, by: 7) }
        .to have_broadcasted_to(session).from_channel(ConsoleSession.channel)
        .with(hash_including("type" => "result"))

      expect(session.reload.result).to include("output" => "2\n", "by" => 7)
    end
  end
end
