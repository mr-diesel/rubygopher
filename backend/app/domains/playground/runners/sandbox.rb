require "json"
require "net/http"

module Playground
  module Runners
    # Hands the snippet to sandboxd (services/sandboxd); nothing user-written runs here.
    class Sandbox
      OPEN_TIMEOUT = 2
      READ_SLACK = 25 # sandboxd enforces the real timeout (plus Rails boot); this only guards a hung connection

      def self.url
        ENV["SANDBOX_URL"]
      end

      def self.token
        ENV["SANDBOX_TOKEN"]
      end

      def self.configured?
        url.present?
      end

      def self.call(code, context:, timeout:)
        uri = URI.join(url, "/eval")
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = timeout + READ_SLACK

        body = JSON.generate(code: code, context: context, timeout: timeout)
        response = http.post(uri.path, body, headers)
        return unexpected(response) unless response.is_a?(Net::HTTPOK)

        JSON.parse(response.body, symbolize_names: true).slice(:output, :error)
      rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError, JSON::ParserError => e
        unavailable(e)
      end

      def self.headers
        { "Content-Type" => "application/json" }.tap do |h|
          h["Authorization"] = "Bearer #{token}" if token.present?
        end
      end

      def self.unexpected(response)
        { output: "", error: { class: "ConsoleError", message: "sandbox answered #{response.code}: #{response.body.to_s.truncate(200)}" } }
      end

      def self.unavailable(error)
        { output: "", error: { class: "SandboxUnavailable", message: "#{error.class}: #{error.message}" } }
      end
    end
  end
end
