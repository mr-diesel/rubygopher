# Streamable HTTP MCP endpoint, stateless: every request is a complete exchange and
# the personal token in the path is the whole authentication.
class McpController < ActionController::API
  def handle
    auth = Identity::Authenticate.call(params[:token])
    return render(json: { error: "invalid token" }, status: :unauthorized) unless auth&.method == :api_token

    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      Agent::Mcp::Server.build(auth.user),
      stateless: true,
      enable_json_response: true,
      serve_subscriptions_listen: false,
      dns_rebinding_protection: false # Rails host authorization already validates Host
    )
    status, headers, body = transport.handle_request(request)
    render(json: body.first, status: status, headers: headers)
  end
end
