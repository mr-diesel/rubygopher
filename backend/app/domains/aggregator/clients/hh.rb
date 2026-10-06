require "net/http"
require "json"

module Aggregator
  module Clients
    # Public hh.ru API, no auth. Returns a vacancy in the shape IngestPosting expects.
    class Hh
      BASE = "https://api.hh.ru".freeze
      USER_AGENT = "RubyGopher/1.0 (https://github.com/mr-diesel/rubygopher)".freeze
      OPEN_TIMEOUT = 3
      READ_TIMEOUT = 5

      class Error < StandardError; end
      class NotFound < Error; end

      def fetch_vacancy(id)
        normalize(get("/vacancies/#{id}"))
      end

      private

      def get(path)
        uri = URI("#{BASE}#{path}")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = READ_TIMEOUT

        response = http.get(uri.path, "User-Agent" => USER_AGENT, "Accept" => "application/json")
        case response
        when Net::HTTPOK then JSON.parse(response.body)
        when Net::HTTPNotFound then raise NotFound, "hh.ru vacancy not found: #{path}"
        else raise Error, "hh.ru answered #{response.code} for #{path}"
        end
      rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError, JSON::ParserError => e
        raise Error, "hh.ru unavailable: #{e.class}: #{e.message}"
      end

      def normalize(data)
        employer = data["employer"] || {}
        salary = data["salary"] || {}
        {
          source: "hh",
          external_id: data["id"].to_s,
          url: data["alternate_url"],
          title: data["name"],
          company: { name: employer["name"], external_id: employer["id"]&.to_s, website: employer["alternate_url"] },
          location: data.dig("area", "name"),
          work_mode: data.dig("schedule", "id") == "remote" ? "remote" : nil,
          salary_min: salary["from"],
          salary_max: salary["to"],
          currency: salary["currency"],
          description: data["description"],
          published_at: data["published_at"],
          raw: data
        }.compact
      end
    end
  end
end
