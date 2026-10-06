module Tracker
  module API
    module Entities
      class Outreach < Grape::Entity
        expose :id, :status, :sent_at, :notes
        expose :company do |outreach|
          { id: outreach.company.id, name: outreach.company.name }
        end
        expose :events, using: OutreachEvent, if: { full: true }
      end
    end
  end
end
