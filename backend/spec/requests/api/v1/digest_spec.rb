require "rails_helper"

RSpec.describe "API V1 Digest", type: :request do
  let(:user) { create(:user) }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/digest" do
    it "requires authentication" do
      get "/api/v1/digest"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns due and upcoming follow-ups with the new vacancy count" do
      due = create(:job_application, user: user, next_follow_up_at: 1.hour.ago)
      upcoming = create(:job_application, user: user, next_follow_up_at: 2.days.from_now)

      get "/api/v1/digest", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("follow_ups", "due").map { |a| a["id"] }).to eq([ due.id ])
      expect(response.parsed_body.dig("follow_ups", "upcoming").map { |a| a["id"] }).to eq([ upcoming.id ])
      expect(response.parsed_body.dig("follow_ups", "due").first["company"]).to include("name" => due.company.name)
      expect(response.parsed_body["new_vacancies"]).to include("count" => 0)
    end
  end

  describe "POST /api/v1/digest/vacancies_seen" do
    it "stamps the feed as seen" do
      post "/api/v1/digest/vacancies_seen", headers: auth_headers

      expect(response).to have_http_status(:no_content)
      expect(user.reload.vacancies_seen_at).to be_within(2.seconds).of(Time.current)
    end
  end
end
