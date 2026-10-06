module Tracker
  module API
    module Entities
      class OutreachEvent < Grape::Entity
        expose :id, :status, :comment, :changed_at
      end
    end
  end
end
