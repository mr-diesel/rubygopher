module Notifications
  module Operations
    # Issues the code the user sends to the bot; a fresh code replaces any earlier one.
    class StartTelegramLink < Dry::Operation
      CODE_LENGTH = 10

      def call(user)
        user.update!(telegram_link_code: SecureRandom.base58(CODE_LENGTH))
        user.telegram_link_code
      end
    end
  end
end
