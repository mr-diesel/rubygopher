require "rails_helper"

RSpec.describe "API V1 Authentication", type: :request do
  describe "POST /api/v1/signup" do
    let(:params) { { email: "new@example.com", password: "password123", name: "New" } }

    it "creates a user and returns a token" do
      expect {
        post "/api/v1/signup", params: params, as: :json
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["token"]).to be_present
      expect(response.parsed_body.dig("user", "email")).to eq("new@example.com")
    end

    it "rejects a short password" do
      post "/api/v1/signup", params: params.merge(password: "short"), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to have_key("password")
    end

    it "rejects a duplicate email" do
      create(:user, email: "new@example.com")

      post "/api/v1/signup", params: params, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to have_key("email")
    end
  end

  describe "POST /api/v1/login" do
    let!(:user) { create(:user, email: "seeker@example.com", password: "password123") }

    it "returns a token for valid credentials" do
      post "/api/v1/login", params: { email: user.email, password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["token"]).to be_present
    end

    it "rejects invalid credentials" do
      post "/api/v1/login", params: { email: user.email, password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/logout" do
    let!(:user) { create(:user, password: "password123") }

    def login_token
      post "/api/v1/login", params: { email: user.email, password: "password123" }, as: :json
      response.parsed_body["token"]
    end

    it "revokes the token so it can't be reused" do
      token = login_token

      delete "/api/v1/logout", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:no_content)

      delete "/api/v1/logout", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "requires a token" do
      delete "/api/v1/logout"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
