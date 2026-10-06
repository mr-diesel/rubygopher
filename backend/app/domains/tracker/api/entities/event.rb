module Tracker
  module API
    module Entities
      class Event < Grape::Entity
        expose :id, :event_type, :status, :comment, :occurred_at
      end
    end
  end
end
