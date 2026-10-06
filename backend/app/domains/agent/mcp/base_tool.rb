module Agent
  module Mcp
    # Tools get the user through server_context (set per request by McpController)
    # and answer with JSON text, the same shapes the REST API returns.
    class BaseTool < MCP::Tool
      class << self
        def user(server_context)
          server_context.fetch(:user)
        end

        def ok(data)
          MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(data.as_json) } ])
        end

        def failed(failure)
          kind, payload = failure
          message = case kind
          when :invalid then "validation failed: #{payload.to_json}"
          when :duplicate then "already tracked, id #{payload.id}"
          when :not_found then "not found"
          when :unavailable then "external service unavailable: #{payload}"
          else kind.to_s
          end
          MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
        end

        def present(result, entity, **options)
          result.success? ? ok(entity.represent(result.value!, **options)) : failed(result.failure)
        end
      end
    end
  end
end
