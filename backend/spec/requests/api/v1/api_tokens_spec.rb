require "rails_helper"

RSpec.describe "API V1 personal API token", type: :request do
  let(:user) { create(:user) }

  def jwt_headers
    token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    { "Authorization" => "Bearer #{token}" }
  end

  it "issues, shows and revokes the token from a portal session" do
    post "/api/v1/me/api_token", headers: jwt_headers

    expect(response).to have_http_status(:created)
    token = response.parsed_body["token"]
    expect(token).to start_with("rg_")
    expect(user.reload.api_token).to eq(token)

    get "/api/v1/me/api_token", headers: jwt_headers
    expect(response.parsed_body).to include("token" => token)

    delete "/api/v1/me/api_token", headers: jwt_headers
    expect(response).to have_http_status(:no_content)
    expect(user.reload.api_token).to be_nil
  end

  it "lets the token use the tracker API" do
    token = user.regenerate_api_token!
    create(:job_application, user: user)

    get "/api/v1/applications", headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.size).to eq(1)
  end

  it "does not let the token rotate or reveal itself" do
    token = user.regenerate_api_token!
    headers = { "Authorization" => "Bearer #{token}" }

    post "/api/v1/me/api_token", headers: headers
    expect(response).to have_http_status(:forbidden)

    get "/api/v1/me/api_token", headers: headers
    expect(response).to have_http_status(:forbidden)
    expect(user.reload.api_token).to eq(token)
  end
end
