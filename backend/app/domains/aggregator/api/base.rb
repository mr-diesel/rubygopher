module Aggregator
  module API
    class Base < Grape::API
      format :json

      mount Aggregator::API::Vacancies
    end
  end
end
