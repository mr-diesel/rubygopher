module Identity
  module API
    class Base < Grape::API
      format :json

      mount Identity::API::Registrations
      mount Identity::API::Sessions
      mount Identity::API::ApiTokens
    end
  end
end
