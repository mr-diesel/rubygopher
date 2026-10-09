require "rails_helper"

RSpec.describe "API V1 Console sessions", type: :request do
  let(:user) { create(:user) }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "POST /api/v1/console/sessions" do
    it "requires authentication" do
      post "/api/v1/console/sessions", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a session with the given snippet" do
      post "/api/v1/console/sessions", params: { code: "p 1", context: "ruby" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("code" => "p 1", "context" => "ruby", "result" => nil)
      expect(response.parsed_body["token"]).to be_present
    end
  end

  describe "GET /api/v1/console/sessions/:token" do
    let(:session) { create(:console_session) }

    it "returns the session state" do
      get "/api/v1/console/sessions/#{session.token}", headers: auth_headers

      expect(response.parsed_body).to include("token" => session.token, "code" => session.code)
    end

    it "is 404 for an unknown token" do
      get "/api/v1/console/sessions/nope", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end

    it "is 404 for an expired session" do
      stale = create(:console_session, updated_at: (ConsoleSession::TTL + 1.day).ago)

      get "/api/v1/console/sessions/#{stale.token}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/console/eval with a session" do
    let(:session) { create(:console_session) }

    before do
      allow(Playground::RateLimit).to receive(:consume).and_return(Playground::RateLimit::Verdict.new(allowed: true, retry_after: 0))
      allow(Playground::Runners::Sandbox).to receive(:url).and_return(nil)
    end

    it "stores the result on the session and broadcasts it" do
      expect {
        post "/api/v1/console/eval", params: { code: "p 1 + 1", context: "ruby", session: session.token }, headers: auth_headers, as: :json
      }.to have_broadcasted_to(session).from_channel(ConsoleSession.channel).with(hash_including("type" => "result"))

      expect(response).to have_http_status(:created)
      expect(session.reload.result).to include("output" => "2\n", "by" => user.id)
    end

    it "is 404 for an unknown session" do
      post "/api/v1/console/eval", params: { code: "p 1", context: "ruby", session: "nope" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
