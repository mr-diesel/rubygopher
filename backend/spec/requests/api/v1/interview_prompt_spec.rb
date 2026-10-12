require "rails_helper"

RSpec.describe "API V1 Interview prompt", type: :request do
  let(:user) { create(:user, resume: "Rails and PostgreSQL") }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  it "requires authentication" do
    get "/api/v1/interview/prompt"

    expect(response).to have_http_status(:unauthorized)
  end

  it "builds the prompt for one of the user's applications" do
    kafka = create(:skill, name: "Kafka", slug: "kafka")
    application = create(:job_application, user: user, vacancy: create(:vacancy, title: "Go dev", skills: [ kafka ]))

    get "/api/v1/interview/prompt", params: { application_id: application.id }, headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("application_id" => application.id, "missing_skills" => [ "Kafka" ])
    expect(response.parsed_body["title"]).to start_with("Mock interview: Go dev")
    expect(response.parsed_body["prompt"]).to include("Rails and PostgreSQL")
  end

  it "builds a general prompt without an application" do
    get "/api/v1/interview/prompt", headers: auth_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("application_id" => nil)
  end

  it "answers 404 for another user's application" do
    other = create(:job_application)

    get "/api/v1/interview/prompt", params: { application_id: other.id }, headers: auth_headers

    expect(response).to have_http_status(:not_found)
  end
end
