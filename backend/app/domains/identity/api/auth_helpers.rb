module Identity
  module API
    module AuthHelpers
      def current_user
        return @current_user if defined?(@current_user)

        @current_user = Identity::Authenticate.call(headers["Authorization"]&.split&.last)
      end

      def authenticate!
        error!({ error: "unauthorized" }, 401) unless current_user
      end
    end
  end
end
