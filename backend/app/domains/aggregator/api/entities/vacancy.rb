module Aggregator
  module API
    module Entities
      class Vacancy < Grape::Entity
        expose :id, :title, :language, :work_mode, :location, :salary_min, :salary_max, :currency, :published_at, :created_at
        expose :company do |vacancy|
          { id: vacancy.company.id, name: vacancy.company.name, website: vacancy.company.website }
        end
        expose :postings do |vacancy|
          vacancy.postings.map { |p| { source: p.source, url: p.url, active: p.active, last_seen_at: p.last_seen_at } }
        end
        expose(:new) { |vacancy, _| vacancy.new_for_user }
        expose :application_id
      end
    end
  end
end
