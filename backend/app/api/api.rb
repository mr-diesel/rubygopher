class API < Grape::API
  mount Identity::API::Base => "/api/v1"
end
