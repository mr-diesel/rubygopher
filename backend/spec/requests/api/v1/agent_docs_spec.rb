require "rails_helper"

RSpec.describe "API V1 agent docs", type: :request do
  it "serves an OpenAPI 3 schema built from the routes, without auth" do
    get "/api/v1/openapi.json"

    expect(response).to have_http_status(:ok)
    doc = response.parsed_body
    expect(doc["openapi"]).to start_with("3.")
    expect(doc["servers"].first["url"]).to eq("http://localhost")
    expect(doc.dig("components", "securitySchemes", "bearerAuth", "scheme")).to eq("bearer")

    create = doc.dig("paths", "/api/v1/applications", "post")
    expect(create["summary"]).to include("Record an application")
    expect(create.dig("requestBody", "content", "application/json", "schema", "properties", "url", "type")).to eq("string")
    expect(create.dig("requestBody", "content", "application/json", "schema", "properties", "language", "enum")).to eq(%w[ruby go other])

    events = doc.dig("paths", "/api/v1/applications/{id}/events", "post")
    expect(events["parameters"]).to include(hash_including("name" => "id", "in" => "path"))
    expect(events.dig("requestBody", "content", "application/json", "schema", "required")).to eq([ "event_type" ])

    expect(doc.dig("paths", "/api/v1/applications", "get", "parameters").map { |p| p["name"] }).to include("status")
    expect(doc.dig("paths", "/api/v1/login", "post", "security")).to eq([])
    expect(doc["paths"].keys).not_to include("/api/v1/console/eval", "/api/v1/openapi.json")
  end

  it "serves the agent guide as markdown" do
    get "/api/v1/agent/guide"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("POST /api/v1/applications")
  end
end
