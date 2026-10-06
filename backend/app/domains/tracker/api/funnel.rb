module Tracker
  module API
    class Funnel < Grape::API
      helpers Identity::API::AuthHelpers, Tracker::API::Helpers

      before { authenticate! }

      desc "Pipeline funnel: how many applications reached each stage, conversions, response rate"
      params do
        optional :since, type: DateTime, desc: "only applications/outreach sent after this moment"
      end
      get :funnel do
        Queries::Funnel.new(current_user, since: input["since"]).call
      end
    end
  end
end
