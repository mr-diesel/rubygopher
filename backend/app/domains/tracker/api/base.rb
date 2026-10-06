module Tracker
  module API
    class Base < Grape::API
      format :json

      mount Tracker::API::Applications
      mount Tracker::API::Outreaches
    end
  end
end
