module Playground
  module API
    class Base < Grape::API
      format :json

      mount Playground::API::Console
      mount Playground::API::Sessions
    end
  end
end
