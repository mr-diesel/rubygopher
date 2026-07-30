module Identity
  module Operations
    class SignUp
      include Dry::Transaction

      step :validate
      step :create_user
      step :issue_token

      def validate(input)
        result = Contracts::SignUpContract.new.call(input)
        result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
      end

      def create_user(attrs)
        user = User.new(attrs)
        user.save ? Success(user) : Failure(user.errors.to_hash)
      end

      def issue_token(user)
        token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
        Success(user: user, token: token)
      end
    end
  end
end
