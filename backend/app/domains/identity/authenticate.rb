module Identity
  # Turns a bearer credential into a user. Two kinds: the portal's JWT (JTI revocation
  # honoured) and a personal rg_ token for external assistants. Shared by Grape and
  # ActionCable so there is exactly one auth path.
  class Authenticate
    Result = Data.define(:user, :method)

    def self.call(token)
      return if token.blank?

      token.start_with?(User::API_TOKEN_PREFIX) ? api_token(token) : jwt(token)
    end

    def self.api_token(token)
      user = User.find_by_api_token(token)
      return unless user

      user.touch_api_token!
      Result.new(user: user, method: :api_token)
    end

    def self.jwt(token)
      payload = Warden::JWTAuth::TokenDecoder.new.call(token)
      user = User.find_by(id: payload["sub"])
      return if user.nil? || User.jwt_revoked?(payload, user)

      Result.new(user: user, method: :jwt)
    rescue JWT::DecodeError
      nil
    end
  end
end
