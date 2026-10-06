require "rails_helper"
require "karafka/testing/rspec/helpers"

RSpec.describe Notifications::Consumers::TelegramLinksConsumer do
  include Karafka::Testing::RSpec::Helpers

  subject(:consumer) { karafka.consumer_for("telegram.links") }

  it "links the chat to the user who owns the code" do
    user = create(:user, telegram_link_code: "xyz")
    karafka.produce({ code: "xyz", chat_id: 777 }.to_json)

    consumer.consume

    expect(user.reload.telegram_chat_id).to eq(777)
  end

  it "ignores unknown codes without raising" do
    karafka.produce({ code: "nope", chat_id: 1 }.to_json)

    expect { consumer.consume }.not_to raise_error
  end
end
