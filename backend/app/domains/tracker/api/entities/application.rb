module Tracker
  module API
    module Entities
      class Application < Grape::Entity
        expose :id, :status, :apply_url, :applied_at, :last_activity_at, :next_follow_up_at, :archived_at
        expose :company do |application|
          { id: application.company.id, name: application.company.name }
        end
        expose :vacancy do |application|
          application.vacancy.slice(:id, :title, :language, :work_mode, :location).merge(url: application.via_posting&.url)
        end
        expose :events, using: Event, if: { full: true }
      end
    end
  end
end
