require "rails_helper"

RSpec.describe Playground::Channels::ConsoleSessionChannel, type: :channel do
  let(:user) { create(:user) }
  let(:session) { create(:console_session, code: "p 1", context: "ruby") }

  before do
    stub_connection(current_user: user)
    Playground::Presence.redis.del(Playground::Presence.key(session))
  end

  it "sends the current state and participant count on subscribe" do
    subscribe(token: session.token)

    expect(subscription).to be_confirmed
    expect(transmissions.last).to include("type" => "state", "code" => "p 1", "context" => "ruby", "participants" => 1)
  end

  it "announces joins and leaves" do
    expect { subscribe(token: session.token) }
      .to have_broadcasted_to(session).from_channel(described_class).with("type" => "presence", "participants" => 1)

    expect { unsubscribe }
      .to have_broadcasted_to(session).from_channel(described_class)
      .with("type" => "presence", "participants" => 0, "left" => user.id)
  end

  it "rejects an expired session" do
    stale = create(:console_session, updated_at: (ConsoleSession::TTL + 1.day).ago)

    subscribe(token: stale.token)

    expect(subscription).to be_rejected
  end

  it "relays cursor positions with the author's name" do
    subscribe(token: session.token)

    expect { perform(:cursor, pos: 12) }
      .to have_broadcasted_to(session).from_channel(described_class)
      .with("type" => "cursor", "by" => user.id, "name" => user.name, "pos" => 12)
  end

  it "rejects an unknown token" do
    subscribe(token: "nope")

    expect(subscription).to be_rejected
  end

  it "stores an update and broadcasts it with the author" do
    subscribe(token: session.token)

    expect { perform(:update, code: "p 2", context: "go") }
      .to have_broadcasted_to(session).from_channel(described_class)
      .with(hash_including("type" => "state", "code" => "p 2", "context" => "go", "by" => user.id))
    expect(session.reload).to have_attributes(code: "p 2", context: "go")
  end

  it "relays that someone started a run" do
    subscribe(token: session.token)

    expect { perform(:running) }
      .to have_broadcasted_to(session).from_channel(described_class).with("type" => "running", "by" => user.id)
  end
end
