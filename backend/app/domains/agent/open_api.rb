module Agent
  # Builds an OpenAPI 3 document from the mounted Grape routes, so the schema an
  # assistant imports can never drift from the endpoints.
  class OpenApi
    SKIP = [ %r{/console}, %r{/openapi}, %r{/agent/} ].freeze
    PUBLIC = [ "POST /api/v1/login", "POST /api/v1/signup" ].freeze

    TYPES = {
      "String" => { type: "string" }, "Integer" => { type: "integer" }, "Float" => { type: "number" },
      "Boolean" => { type: "boolean" }, "Grape::API::Boolean" => { type: "boolean" },
      "DateTime" => { type: "string", format: "date-time" }, "Date" => { type: "string", format: "date" },
      "Hash" => { type: "object" }, "JSON" => { type: "object" }
    }.freeze

    def initialize(routes = ::API.routes, server:)
      @routes = routes
      @server = server
    end

    def build
      {
        openapi: "3.1.0",
        info: { title: "RubyGopher API", version: "1", description: "Job-search tracker: applications, cold outreach, follow-ups." },
        servers: [ { url: @server } ],
        components: { securitySchemes: { bearerAuth: { type: "http", scheme: "bearer", description: "Personal token from the portal (rg_...) or a portal JWT" } } },
        security: [ { bearerAuth: [] } ],
        paths: paths
      }
    end

    private

    def paths
      @routes.reject { |r| SKIP.any? { |re| r.path.match?(re) } }.each_with_object({}) do |route, acc|
        path = route.path.sub(/\(\.json\)\z/, "").gsub(/:(\w+)/, '{\1}')
        acc[path] ||= {}
        acc[path][route.request_method.downcase] = operation(route, path)
      end
    end

    def operation(route, path)
      op = {
        summary: route.description || "#{route.request_method} #{path}",
        tags: [ path.split("/")[3] ],
        responses: { "200" => { description: "OK" }, "401" => { description: "Missing or invalid token" }, "422" => { description: "Validation errors" } }
      }
      op[:security] = [] if PUBLIC.include?("#{route.request_method} #{path}")

      path_params = path.scan(/\{(\w+)\}/).flatten
      params = route.params.reject { |name, _| path_params.include?(name) }
      op[:parameters] = path_params.map { |name| { name: name, in: "path", required: true, schema: { type: "integer" } } }

      if %w[GET DELETE].include?(route.request_method)
        op[:parameters] += params.map { |name, spec| { name: name, in: "query", required: spec[:required] == true, schema: schema(spec) } }
      elsif params.any?
        op[:requestBody] = {
          required: true,
          content: { "application/json" => { schema: {
            type: "object",
            properties: params.to_h { |name, spec| [ name, schema(spec) ] },
            required: params.select { |_, spec| spec[:required] == true }.keys
          } } }
        }
      end
      op
    end

    def schema(spec)
      base = TYPES.fetch(spec[:type].to_s) { spec[:type].to_s.start_with?("[") ? { type: "array", items: { type: "integer" } } : { type: "string" } }
      base = base.merge(enum: spec[:values]) if spec[:values].is_a?(Array)
      base = base.merge(description: spec[:desc]) if spec[:desc]
      base = base.merge(default: spec[:default]) unless spec[:default].nil?
      base
    end
  end
end
