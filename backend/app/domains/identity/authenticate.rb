module Identity
  # Turns a bearer JWT into a User, honouring Devise's JTI revocation. Shared by the
  # Grape API and the ActionCable connection so there is exactly one auth path.
  class Authenticate
    def self.call(token)
      return if token.blank?

      payload = Warden::JWTAuth::TokenDecoder.new.call(token)
      user = User.find_by(id: payload["sub"])
      return if user.nil? || User.jwt_revoked?(payload, user)

      user
    rescue JWT::DecodeError
      nil
    end
  end
end
