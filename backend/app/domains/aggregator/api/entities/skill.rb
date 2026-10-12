module Aggregator
  module API
    module Entities
      class Skill < Grape::Entity
        expose :slug, :name, :category
        expose(:vacancies_count, if: ->(_, options) { options.key?(:vacancies_count) }) { |_, options| options[:vacancies_count] }
      end
    end
  end
end
