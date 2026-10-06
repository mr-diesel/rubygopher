require "dry/operation/extensions/active_record"

module Tracker
  module Operations
    # One application per (user, vacancy). The vacancy comes from the pasted job-board
    # link when we know it (or can fetch it), otherwise from company and title, which
    # are matched by name so an assistant retrying the same call cannot create duplicates.
    class RecordApplication < Dry::Operation
      include Dry::Operation::Extensions::ActiveRecord

      def initialize(hh: Aggregator::Clients::Hh.new)
        @hh = hh
      end

      def call(user, input)
        attrs = step validate(input)
        posting = step resolve_posting(attrs)

        transaction do
          vacancy = posting&.vacancy || find_or_create_vacancy(find_or_create_company(attrs[:company_name]), attrs)
          step ensure_untracked(user, vacancy)
          application = step create_application(user, vacancy, posting, attrs)
          step record_event(application, attrs)
          Events.application_recorded(application)
          application
        end
      end

      private

      def validate(input)
        result = Contracts::RecordApplicationContract.new.call(input)
        result.success? ? Success(result.to_h) : Failure([ :invalid, result.errors.to_h ])
      end

      # A known board link resolves to its posting; an unknown hh link is fetched and
      # ingested on the spot; anything else falls back to company + title.
      def resolve_posting(attrs)
        ref = Aggregator::Sources.parse(attrs[:url])
        return Success(nil) unless ref

        posting = VacancyPosting.find_by(ref)
        return Success(posting) if posting
        return Success(nil) if attrs[:company_name].present? && attrs[:vacancy_title].present?
        return Failure([ :invalid, { url: [ "this vacancy is not collected yet; add company_name and vacancy_title" ] } ]) unless ref[:source] == "hh"

        ingest(@hh.fetch_vacancy(ref[:external_id]))
      rescue Aggregator::Clients::Hh::NotFound
        Failure([ :invalid, { url: [ "hh.ru does not know this vacancy" ] } ])
      rescue Aggregator::Clients::Hh::Error => e
        Failure([ :unavailable, e.message ])
      end

      def ingest(posting_attrs)
        result = Aggregator::Operations::IngestPosting.new.call(posting_attrs)
        result.success? ? Success(result.value!) : Failure([ :invalid, { url: [ "hh.ru returned an unusable vacancy" ] } ])
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

      def create_application(user, vacancy, posting, attrs)
        applied_at = attrs[:applied_at] || Time.current
        Success(user.job_applications.create!(
          company: vacancy.company, vacancy: vacancy, via_posting: posting, apply_url: attrs[:url] || posting&.url,
          status: :applied, applied_at: applied_at, last_activity_at: applied_at, next_follow_up_at: attrs[:next_follow_up_at]
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
