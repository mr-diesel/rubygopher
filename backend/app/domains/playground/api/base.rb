module Playground
  module API
    class Base < Grape::API
      format :json

      mount Playground::API::Console
    end
  end
end
