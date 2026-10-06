module Notifications
  module API
    class Telegram < Grape::API
      helpers Identity::API::AuthHelpers

      before { authenticate! }

      helpers do
        def telegram_status
          bot = ENV["TELEGRAM_BOT_USERNAME"].presence
          code = current_user.telegram_link_code
          {
            linked: current_user.telegram_chat_id.present?,
            bot: bot,
            code: code,
            link_url: bot && code && "https://t.me/#{bot}?start=#{code}"
          }
        end
      end

      resource "me/telegram" do
        get { telegram_status }

        post :link do
          Operations::StartTelegramLink.new.call(current_user)
          telegram_status
        end

        delete do
          current_user.update!(telegram_chat_id: nil, telegram_link_code: nil)
          status 204
          body false
        end
      end
    end
  end
end
