require "rails_helper"

RSpec.describe "API V1 Profile", type: :request do
  let(:user) { create(:user, name: "Pavel") }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/me" do
    it "requires authentication" do
      get "/api/v1/me"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the profile" do
      get "/api/v1/me", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("email" => user.email, "name" => "Pavel", "resume" => nil)
    end
  end

  describe "PATCH /api/v1/me" do
    it "stores the résumé, also with the personal API token" do
      patch "/api/v1/me", params: { resume: "Ruby, 5 years" }, headers: { "Authorization" => "Bearer #{user.regenerate_api_token!}" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["resume"]).to eq("Ruby, 5 years")
    end

    it "returns 422 for an oversized résumé" do
      patch "/api/v1/me", params: { resume: "x" * 20_001 }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("resume")
    end
  end
end
