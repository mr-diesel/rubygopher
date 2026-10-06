require "rails_helper"

RSpec.describe Notifications::Operations::LinkTelegram do
  let!(:user) { create(:user, telegram_link_code: "abc123") }

  it "stores the chat, burns the code and announces it on the outbox" do
    result = described_class.new.call(code: "abc123", chat_id: 42)

    expect(result).to be_success
    expect(user.reload).to have_attributes(telegram_chat_id: 42, telegram_link_code: nil)
    expect(Outbox::Event.sole).to have_attributes(event_type: "user.telegram_linked", key: "user:#{user.id}")
    expect(Outbox::Event.sole.payload).to include("telegram_chat_id" => 42)
  end

  it "fails softly on an unknown or replayed code" do
    described_class.new.call(code: "abc123", chat_id: 42)

    expect(described_class.new.call(code: "abc123", chat_id: 43).failure).to eq([ :unknown_code, "abc123" ])
    expect(described_class.new.call(code: "", chat_id: 43).failure.first).to eq(:unknown_code)
    expect(user.reload.telegram_chat_id).to eq(42)
  end
end
