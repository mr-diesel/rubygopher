module Agent
  module Mcp
    # One MCP server per request: the user comes from the rg_ token in the URL, so
    # the same tools serve any browser assistant that speaks MCP.
    module Server
      def self.build(user)
        MCP::Server.new(
          name: "rubygopher",
          title: "RubyGopher job tracker",
          version: "1",
          instructions: Agent::Guide.text,
          tools: Tools::ALL,
          resources: [ GuideResource ],
          server_context: { user: user }
        )
      end
    end
  end
end
