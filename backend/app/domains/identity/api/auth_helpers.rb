module Identity
  module API
    module AuthHelpers
      def current_user
        authentication&.user
      end

      def auth_method
        authentication&.method
      end

      def authenticate!
        error!({ error: "unauthorized" }, 401) unless current_user
      end

      # Managing the token itself must not be possible with the token: a leaked
      # rg_ key cannot rotate itself and lock the owner out.
      def require_session!
        authenticate!
        error!({ error: "sign in to the portal to manage API tokens" }, 403) unless auth_method == :jwt
      end

      private

      def authentication
        return @authentication if defined?(@authentication)

        @authentication = Identity::Authenticate.call(headers["Authorization"]&.split&.last)
      end
    end
  end
end
