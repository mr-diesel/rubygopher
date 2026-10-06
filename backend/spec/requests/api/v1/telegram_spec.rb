require "rails_helper"

RSpec.describe "API V1 Telegram link", type: :request do
  let(:user) { create(:user) }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  around do |example|
    ENV["TELEGRAM_BOT_USERNAME"] = "rubygopher_bot"
    example.run
  ensure
    ENV.delete("TELEGRAM_BOT_USERNAME")
  end

  it "requires authentication" do
    get "/api/v1/me/telegram"

    expect(response).to have_http_status(:unauthorized)
  end

  it "issues a code and the deep link, then reports linked once the bot replied" do
    post "/api/v1/me/telegram/link", headers: auth_headers

    code = response.parsed_body["code"]
    expect(code).to be_present
    expect(response.parsed_body).to include("linked" => false, "link_url" => "https://t.me/rubygopher_bot?start=#{code}")

    Notifications::Operations::LinkTelegram.new.call(code: code, chat_id: 5)
    get "/api/v1/me/telegram", headers: auth_headers

    expect(response.parsed_body).to include("linked" => true, "code" => nil)
  end

  it "reports no bot when the username is not configured" do
    ENV["TELEGRAM_BOT_USERNAME"] = ""

    post "/api/v1/me/telegram/link", headers: auth_headers

    expect(response.parsed_body).to include("bot" => nil, "link_url" => nil)
    expect(response.parsed_body["code"]).to be_present
  end

  it "unlinks" do
    user.update!(telegram_chat_id: 5)

    delete "/api/v1/me/telegram", headers: auth_headers

    expect(response).to have_http_status(:no_content)
    expect(user.reload.telegram_chat_id).to be_nil
  end
end
