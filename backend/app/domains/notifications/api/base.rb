module Notifications
  module API
    class Base < Grape::API
      format :json

      mount Notifications::API::Telegram
    end
  end
end
