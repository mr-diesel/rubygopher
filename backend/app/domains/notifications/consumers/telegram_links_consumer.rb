module Notifications
  module Consumers
    class TelegramLinksConsumer < ApplicationConsumer
      def consume
        messages.each do |message|
          payload = message.payload
          result = Operations::LinkTelegram.new.call(code: payload["code"].to_s, chat_id: payload["chat_id"].to_i)
          Karafka.logger.warn("telegram.links: #{result.failure.inspect}") if result.failure?
          mark_as_consumed(message)
        end
      end
    end
  end
end
