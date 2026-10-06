module Tracker
  module API
    module Helpers
      def input
        declared(params, include_missing: false).to_h.except("id")
      end

      def fail!(failure)
        kind, payload = failure
        case kind
        when :invalid then error!({ errors: payload }, 422)
        when :duplicate then error!({ error: "already tracked", id: payload.id }, 409)
        when :not_found then error!({ error: "not found" }, 404)
        end
      end
    end
  end
end
