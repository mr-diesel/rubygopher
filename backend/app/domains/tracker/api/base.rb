module Tracker
  module API
    class Base < Grape::API
      format :json

      mount Tracker::API::Applications
      mount Tracker::API::Outreaches
      mount Tracker::API::Digest
      mount Tracker::API::Funnel
    end
  end
end
