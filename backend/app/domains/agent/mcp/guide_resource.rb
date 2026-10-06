module Agent
  module Mcp
    class GuideResource < MCP::Resource
      uri "rubygopher://guide"
      resource_name "guide"
      description "How to keep the job-search journal with these tools"
      mime_type "text/markdown"

      def self.contents(server_context: nil)
        [ MCP::Resource::TextContents.new(uri: uri, mime_type: mime_type, text: Agent::Guide.text) ]
      end
    end
  end
end
