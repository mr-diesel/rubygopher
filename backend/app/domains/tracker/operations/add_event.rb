require "dry/operation/extensions/active_record"

module Tracker
  module Operations
    # Appends to the application's history and keeps the denormalised columns
    # (status, last_activity_at, next_follow_up_at) in step with it.
    class AddEvent < Dry::Operation
      include Dry::Operation::Extensions::ActiveRecord

      def call(user, application_id, input)
        attrs = step validate(input)
        application = step find_application(user, application_id)

        transaction do
          event = step create_event(application, attrs)
          step update_application(application, attrs, event)
          Events.application_event_added(application, event)
          event
        end
      end

      private

      def validate(input)
        result = Contracts::AddEventContract.new.call(input)
        result.success? ? Success(result.to_h) : Failure([ :invalid, result.errors.to_h ])
      end

      def find_application(user, id)
        application = user.job_applications.find_by(id: id)
        application ? Success(application) : Failure([ :not_found ])
      end

      def create_event(application, attrs)
        Success(application.events.create!(
          event_type: attrs[:event_type], status: attrs[:status], comment: attrs[:comment],
          occurred_at: attrs[:occurred_at] || Time.current
        ))
      end

      def update_application(application, attrs, event)
        changes = { last_activity_at: event.occurred_at }
        changes[:status] = attrs[:status] if event.status_changed?
        changes[:next_follow_up_at] = attrs[:next_follow_up_at] if attrs.key?(:next_follow_up_at)
        Success(application.update!(changes))
      end
    end
  end
end
