module Identity
  module API
    module AuthHelpers
      def current_user
        return @current_user if defined?(@current_user)

        @current_user = authenticate_from_token
      end

      def authenticate!
        error!({ error: "unauthorized" }, 401) unless current_user
      end

      private

      def authenticate_from_token
        token = headers["Authorization"]&.split&.last
        return unless token

        payload = Warden::JWTAuth::TokenDecoder.new.call(token)
        user = User.find_by(id: payload["sub"])
        return if user.nil? || User.jwt_revoked?(payload, user)

        user
      rescue JWT::DecodeError
        nil
      end
    end
  end
end
