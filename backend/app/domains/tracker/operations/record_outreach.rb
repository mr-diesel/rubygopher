require "dry/operation/extensions/active_record"

module Tracker
  module Operations
    # One outreach per (user, company): a cold email or message sent outside the app,
    # recorded here with its first "no response" state.
    class RecordOutreach < Dry::Operation
      include Dry::Operation::Extensions::ActiveRecord

      def call(user, input)
        attrs = step validate(input)

        transaction do
          company = Company.named(attrs[:company_name]).first || Company.create!(name: attrs[:company_name], source: :manual)
          step ensure_untracked(user, company)
          outreach = step create_outreach(user, company, attrs)
          step record_event(outreach)
          outreach
        end
      end

      private

      def validate(input)
        result = Contracts::RecordOutreachContract.new.call(input)
        result.success? ? Success(result.to_h) : Failure([ :invalid, result.errors.to_h ])
      end

      def ensure_untracked(user, company)
        existing = user.company_outreaches.find_by(company: company)
        existing ? Failure([ :duplicate, existing ]) : Success(nil)
      end

      def create_outreach(user, company, attrs)
        Success(user.company_outreaches.create!(
          company: company, status: :no_response, sent_at: attrs[:sent_at] || Time.current, notes: attrs[:notes]
        ))
      end

      def record_event(outreach)
        Success(outreach.events.create!(status: :no_response, changed_at: outreach.sent_at))
      end
    end
  end
end
