require "rails_helper"

RSpec.describe "MCP endpoint", type: :request do
  let(:user) { create(:user) }
  let(:token) { user.regenerate_api_token! }

  def rpc(method, params = {}, id: 1, token: self.token)
    post "/mcp/#{token}", params: { jsonrpc: "2.0", id: id, method: method, params: params }.to_json,
                          headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
    response.parsed_body
  end

  it "rejects a missing, wrong or portal-session token" do
    rpc("ping", token: "rg_nope")
    expect(response).to have_http_status(:unauthorized)

    jwt, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    rpc("ping", token: jwt)
    expect(response).to have_http_status(:unauthorized)
  end

  it "initializes and lists the tracker tools" do
    init = rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "spec", version: "1" } })

    expect(init.dig("result", "serverInfo", "name")).to eq("rubygopher")
    expect(init.dig("result", "instructions")).to include("POST /api/v1/applications")

    tools = rpc("tools/list").dig("result", "tools").map { |t| t["name"] }
    expect(tools).to include("record_application", "add_application_event", "list_applications", "digest", "funnel")
  end

  it "records an application through a tool call and reads it back" do
    result = rpc("tools/call", { name: "record_application", arguments: { company_name: "Acme", vacancy_title: "Ruby dev", comment: "via chat" } })

    expect(result.dig("result", "isError")).to be_falsey
    payload = JSON.parse(result.dig("result", "content", 0, "text"))
    expect(payload).to include("status" => "applied")
    expect(payload["company"]).to include("name" => "Acme")
    expect(user.job_applications.count).to eq(1)

    listed = JSON.parse(rpc("tools/call", { name: "list_applications", arguments: {} }).dig("result", "content", 0, "text"))
    expect(listed.map { |a| a["id"] }).to eq([ payload["id"] ])
  end

  it "reports domain failures as tool errors, not protocol errors" do
    rpc("tools/call", { name: "record_application", arguments: { company_name: "Acme", vacancy_title: "Ruby dev" } })
    dup = rpc("tools/call", { name: "record_application", arguments: { company_name: "acme", vacancy_title: "ruby dev" } })

    expect(dup.dig("result", "isError")).to be(true)
    expect(dup.dig("result", "content", 0, "text")).to include("already tracked")

    missing = rpc("tools/call", { name: "get_application", arguments: { application_id: 999_999 } })
    expect(missing.dig("result", "isError")).to be(true)
  end

  it "keeps users apart" do
    create(:job_application)

    listed = JSON.parse(rpc("tools/call", { name: "list_applications", arguments: {} }).dig("result", "content", 0, "text"))
    expect(listed).to eq([])
  end

  it "serves the guide as a resource" do
    expect(rpc("resources/list").dig("result", "resources").map { |r| r["uri"] }).to eq([ "rubygopher://guide" ])

    read = rpc("resources/read", { uri: "rubygopher://guide" })
    expect(read.dig("result", "contents", 0, "text")).to include("RubyGopher agent guide")
  end
end
