require "dry/operation/extensions/active_record"

module Tracker
  module Operations
    # One application per (user, vacancy). Company and vacancy are matched by name so
    # an assistant retrying the same call cannot create duplicates.
    class RecordApplication < Dry::Operation
      include Dry::Operation::Extensions::ActiveRecord

      def call(user, input)
        attrs = step validate(input)

        transaction do
          company = find_or_create_company(attrs[:company_name])
          vacancy = find_or_create_vacancy(company, attrs)
          step ensure_untracked(user, vacancy)
          application = step create_application(user, company, vacancy, attrs)
          step record_event(application, attrs)
          application
        end
      end

      private

      def validate(input)
        result = Contracts::RecordApplicationContract.new.call(input)
        result.success? ? Success(result.to_h) : Failure([ :invalid, result.errors.to_h ])
      end

      def find_or_create_company(name)
        Company.named(name).first || Company.create!(name: name, source: :manual)
      end

      def find_or_create_vacancy(company, attrs)
        company.vacancies.titled(attrs[:vacancy_title]).first ||
          company.vacancies.create!(attrs.slice(:language, :work_mode, :location).compact.merge(title: attrs[:vacancy_title]))
      end

      def ensure_untracked(user, vacancy)
        existing = user.job_applications.find_by(vacancy: vacancy)
        existing ? Failure([ :duplicate, existing ]) : Success(nil)
      end

      def create_application(user, company, vacancy, attrs)
        applied_at = attrs[:applied_at] || Time.current
        Success(user.job_applications.create!(
          company: company, vacancy: vacancy, apply_url: attrs[:apply_url], status: :applied,
          applied_at: applied_at, last_activity_at: applied_at, next_follow_up_at: attrs[:next_follow_up_at]
        ))
      end

      def record_event(application, attrs)
        Success(application.events.create!(
          event_type: :status_changed, status: :applied, comment: attrs[:comment], occurred_at: application.applied_at
        ))
      end
    end
  end
end
