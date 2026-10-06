module Notifications
  module Operations
    # Completes the link started in the portal: the bot forwarded /start <code> with
    # the chat it came from. Idempotent: a replayed message finds the code gone and fails softly.
    class LinkTelegram < Dry::Operation
      def call(code:, chat_id:)
        user = step find_user(code)
        user.update!(telegram_chat_id: chat_id, telegram_link_code: nil)
        Tracker::Events.telegram_linked(user)
        user
      end

      private

      def find_user(code)
        user = code.present? && User.find_by(telegram_link_code: code)
        user ? Success(user) : Failure([ :unknown_code, code ])
      end
    end
  end
end
