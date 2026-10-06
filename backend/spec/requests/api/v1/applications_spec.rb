require "rails_helper"

RSpec.describe "API V1 Applications", type: :request do
  let(:user) { create(:user) }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/applications" do
    it "requires authentication" do
      get "/api/v1/applications"

      expect(response).to have_http_status(:unauthorized)
    end

    it "lists the user's active applications, newest activity first, with company and vacancy" do
      old = create(:job_application, user: user, last_activity_at: 2.days.ago)
      recent = create(:job_application, user: user, last_activity_at: 1.hour.ago)
      create(:job_application, user: user, archived_at: Time.current)
      create(:job_application)

      get "/api/v1/applications", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |a| a["id"] }).to eq([ recent.id, old.id ])
      expect(response.parsed_body.first["company"]).to include("name" => recent.company.name)
      expect(response.parsed_body.first["vacancy"]).to include("title" => recent.vacancy.title)
    end

    it "filters by status" do
      create(:job_application, user: user, status: :offer)
      create(:job_application, user: user, status: :applied)

      get "/api/v1/applications", params: { status: "offer" }, headers: auth_headers

      expect(response.parsed_body.map { |a| a["status"] }).to eq([ "offer" ])
    end
  end

  describe "POST /api/v1/applications" do
    it "records an application and returns it with its events" do
      post "/api/v1/applications", params: { company_name: "Acme", vacancy_title: "Ruby dev", comment: "hi" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("status" => "applied")
      expect(response.parsed_body["events"].sole).to include("event_type" => "status_changed", "comment" => "hi")
    end

    it "accepts ISO 8601 dates" do
      post "/api/v1/applications",
           params: { company_name: "Acme", vacancy_title: "Ruby dev", applied_at: "2026-10-01T10:00:00Z", next_follow_up_at: "2026-10-08T10:00:00Z" },
           headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(JobApplication.sole).to have_attributes(applied_at: Time.utc(2026, 10, 1, 10), next_follow_up_at: Time.utc(2026, 10, 8, 10))
    end

    it "is 409 when the vacancy is already tracked" do
      post "/api/v1/applications", params: { company_name: "Acme", vacancy_title: "Ruby dev" }, headers: auth_headers, as: :json
      post "/api/v1/applications", params: { company_name: "acme", vacancy_title: "ruby dev" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body["id"]).to eq(JobApplication.sole.id)
    end

    it "is 422 with field errors on invalid input" do
      post "/api/v1/applications", params: { company_name: "Acme", vacancy_title: "Dev", apply_url: "nope" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to have_key("apply_url")
    end
  end

  describe "GET /api/v1/applications/:id" do
    it "returns the application with its history" do
      application = create(:job_application, user: user)
      create(:job_application_event, job_application: application, comment: "note")

      get "/api/v1/applications/#{application.id}", headers: auth_headers

      expect(response.parsed_body["events"].map { |e| e["comment"] }).to eq([ "note" ])
    end

    it "is 404 for another user's application" do
      get "/api/v1/applications/#{create(:job_application).id}", headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/applications/:id/events" do
    let(:application) { create(:job_application, user: user) }

    it "appends an event and updates the status" do
      post "/api/v1/applications/#{application.id}/events",
           params: { event_type: "status_changed", status: "tech_interview", comment: "Tuesday" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("event_type" => "status_changed", "status" => "tech_interview")
      expect(application.reload).to be_tech_interview
    end

    it "schedules the next follow-up from a follow_up_sent event" do
      post "/api/v1/applications/#{application.id}/events",
           params: { event_type: "follow_up_sent", next_follow_up_at: "2026-10-20T09:00:00Z" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(application.reload.next_follow_up_at).to eq(Time.utc(2026, 10, 20, 9))
    end

    it "is 422 without a status for status_changed" do
      post "/api/v1/applications/#{application.id}/events", params: { event_type: "status_changed" }, headers: auth_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
