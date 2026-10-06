module Tracker
  module API
    module Helpers
      # Grape coerces `type: DateTime` params into DateTime objects, which dry-schema's
      # `:time` type does not accept; hand the contracts Time instances instead.
      def input
        declared(params, include_missing: false).to_h.except("id")
                                                   .transform_values { |value| value.is_a?(DateTime) ? value.to_time : value }
      end

      def fail!(failure)
        kind, payload = failure
        case kind
        when :invalid then error!({ errors: payload }, 422)
        when :duplicate then error!({ error: "already tracked", id: payload.id }, 409)
        when :not_found then error!({ error: "not found" }, 404)
        when :unavailable then error!({ error: payload }, 503)
        end
      end
    end
  end
end
