class API < Grape::API
  mount Identity::API::Base => "/api/v1"
  mount Interview::API::Base => "/api/v1"
  mount Playground::API::Base => "/api/v1"
  mount Tracker::API::Base => "/api/v1"
  mount Notifications::API::Base => "/api/v1"
end
