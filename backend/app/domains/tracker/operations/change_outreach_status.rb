require "dry/operation/extensions/active_record"

module Tracker
  module Operations
    class ChangeOutreachStatus < Dry::Operation
      include Dry::Operation::Extensions::ActiveRecord

      def call(user, outreach_id, input)
        attrs = step validate(input)
        outreach = step find_outreach(user, outreach_id)

        transaction do
          event = step create_event(outreach, attrs)
          step update_outreach(outreach, event)
          event
        end
      end

      private

      def validate(input)
        result = Contracts::ChangeOutreachStatusContract.new.call(input)
        result.success? ? Success(result.to_h) : Failure([ :invalid, result.errors.to_h ])
      end

      def find_outreach(user, id)
        outreach = user.company_outreaches.find_by(id: id)
        outreach ? Success(outreach) : Failure([ :not_found ])
      end

      def create_event(outreach, attrs)
        Success(outreach.events.create!(
          status: attrs[:status], comment: attrs[:comment], changed_at: attrs[:changed_at] || Time.current
        ))
      end

      def update_outreach(outreach, event)
        Success(outreach.update!(status: event.status))
      end
    end
  end
end
