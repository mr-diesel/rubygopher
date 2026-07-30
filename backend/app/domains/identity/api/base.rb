module Identity
  module API
    class Base < Grape::API
      format :json

      mount Identity::API::Registrations
      mount Identity::API::Sessions
    end
  end
end
