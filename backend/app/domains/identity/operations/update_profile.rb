module Identity
  module Operations
    class UpdateProfile < Dry::Operation
      def call(user, input)
        attrs = step validate(input)
        user.update!(attrs)
        user
      end

      private

      def validate(input)
        result = Contracts::UpdateProfileContract.new.call(input)
        result.success? ? Success(result.to_h) : Failure([ :invalid, result.errors.to_h ])
      end
    end
  end
end
