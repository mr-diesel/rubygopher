module Agent
  module API
    # Public on purpose: the schema holds no secrets and assistants fetch it by URL.
    class Docs < Grape::API
      desc "OpenAPI 3.1 schema of the whole API"
      get "openapi.json" do
        Agent::OpenApi.new(server: request.base_url).build
      end

      desc "How an AI assistant should use this API"
      get "agent/guide" do
        content_type "text/markdown"
        env["api.format"] = :txt
        Agent::Guide.text
      end
    end
  end
end
