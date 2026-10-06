require "rails_helper"

RSpec.describe "API V1 Outreaches", type: :request do
  let(:user) { create(:user) }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/outreaches" do
    it "requires authentication" do
      get "/api/v1/outreaches"

      expect(response).to have_http_status(:unauthorized)
    end

    it "lists the user's outreaches, newest first, optionally filtered by status" do
      old = create(:company_outreach, user: user, sent_at: 2.weeks.ago, status: :talent_pool)
      recent = create(:company_outreach, user: user, sent_at: 1.day.ago)
      create(:company_outreach)

      get "/api/v1/outreaches", headers: auth_headers
      expect(response.parsed_body.map { |o| o["id"] }).to eq([ recent.id, old.id ])

      get "/api/v1/outreaches", params: { status: "talent_pool" }, headers: auth_headers
      expect(response.parsed_body.map { |o| o["id"] }).to eq([ old.id ])
    end
  end

  describe "POST /api/v1/outreaches" do
    it "records an outreach" do
      post "/api/v1/outreaches", params: { company_name: "Acme", notes: "hi" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("status" => "no_response", "notes" => "hi")
      expect(response.parsed_body["events"].sole).to include("status" => "no_response")
    end

    it "accepts an ISO 8601 sent_at" do
      post "/api/v1/outreaches", params: { company_name: "Acme", sent_at: "2026-09-30T08:00:00Z" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(CompanyOutreach.sole.sent_at).to eq(Time.utc(2026, 9, 30, 8))
    end

    it "is 409 for a second outreach to the same company" do
      create(:company_outreach, user: user, company: create(:company, name: "Acme"))

      post "/api/v1/outreaches", params: { company_name: "acme" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:conflict)
    end
  end

  describe "POST /api/v1/outreaches/:id/status" do
    it "changes the status and returns the event" do
      outreach = create(:company_outreach, user: user)

      post "/api/v1/outreaches/#{outreach.id}/status", params: { status: "rejected", comment: "no budget" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("status" => "rejected", "comment" => "no budget")
      expect(outreach.reload).to be_rejected
    end

    it "is 404 for another user's outreach" do
      post "/api/v1/outreaches/#{create(:company_outreach).id}/status", params: { status: "offer" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
