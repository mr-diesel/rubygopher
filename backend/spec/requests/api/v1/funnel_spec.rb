require "rails_helper"

RSpec.describe "API V1 Funnel", type: :request do
  let(:user) { create(:user) }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  it "requires authentication" do
    get "/api/v1/funnel"

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the funnel, optionally since a date" do
    app = create(:job_application, user: user, applied_at: 3.days.ago)
    create(:job_application_event, job_application: app, event_type: :status_changed, status: :screening)
    create(:job_application, user: user, applied_at: 40.days.ago)

    get "/api/v1/funnel", headers: auth_headers
    expect(response.parsed_body.dig("applications", "total")).to eq(2)

    get "/api/v1/funnel", params: { since: 7.days.ago.iso8601 }, headers: auth_headers
    expect(response.parsed_body.dig("applications", "total")).to eq(1)
    expect(response.parsed_body.dig("applications", "stages", 2)).to include("name" => "screening", "count" => 1)
  end
end
