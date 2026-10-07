require "rails_helper"

RSpec.describe "API V1 Vacancies feed", type: :request do
  let(:user) { create(:user, created_at: 1.day.ago) }

  def auth_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  it "requires authentication" do
    get "/api/v1/vacancies"

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the feed with postings, company and the user's marks" do
    vacancy = create(:vacancy, title: "Senior Ruby", language: :ruby, salary_min: 300_000, currency: "RUB")
    create(:vacancy_posting, vacancy: vacancy, source: :hh, url: "https://hh.ru/vacancy/1")
    create(:vacancy_posting, vacancy: vacancy, source: :getmatch, url: "https://getmatch.ru/vacancies/2")

    get "/api/v1/vacancies", params: { language: "ruby" }, headers: auth_headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body).to include("total" => 1, "page" => 1)
    item = body["vacancies"].first
    expect(item).to include("title" => "Senior Ruby", "new" => true, "application_id" => nil, "salary_min" => 300_000)
    expect(item["company"]).to include("name" => vacancy.company.name)
    expect(item["postings"].map { |p| p["source"] }).to contain_exactly("hh", "getmatch")
  end

  it "rejects unknown filter values" do
    get "/api/v1/vacancies", params: { source: "manual" }, headers: auth_headers

    expect(response).to have_http_status(:bad_request)
  end
end
