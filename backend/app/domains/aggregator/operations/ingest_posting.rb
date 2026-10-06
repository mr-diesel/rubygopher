require "dry/operation/extensions/active_record"

module Aggregator
  module Operations
    # Turns one raw posting from a job board into company + canonical vacancy + posting.
    # Idempotent on (source, external_id): a replayed message only refreshes last_seen_at.
    class IngestPosting < Dry::Operation
      include Dry::Operation::Extensions::ActiveRecord

      def call(input)
        attrs = step validate(input)

        transaction do
          posting = VacancyPosting.find_by(source: attrs[:source], external_id: attrs[:external_id])
          next refresh(posting, attrs) if posting

          company = find_or_create_company(attrs)
          vacancy = find_or_create_vacancy(company, attrs)
          vacancy.postings.create!(
            source: attrs[:source], external_id: attrs[:external_id], url: attrs[:url],
            raw: attrs[:raw] || {}, first_seen_at: Time.current, last_seen_at: Time.current
          )
        end
      end

      private

      def validate(input)
        result = Contracts::IngestPostingContract.new.call(input)
        result.success? ? Success(result.to_h) : Failure([ :invalid, result.errors.to_h ])
      end

      def refresh(posting, attrs)
        posting.update!(last_seen_at: Time.current, active: true, url: attrs[:url], raw: attrs[:raw] || posting.raw)
        posting
      end

      def find_or_create_company(attrs)
        company = attrs[:company]
        by_source = company[:external_id] && Company.find_by(source: attrs[:source], external_id: company[:external_id])
        by_source || Company.named(company[:name]).first ||
          Company.create!(name: company[:name], website: company[:website], source: attrs[:source], external_id: company[:external_id])
      end

      def find_or_create_vacancy(company, attrs)
        company.vacancies.titled(attrs[:title]).first ||
          company.vacancies.create!(
            attrs.slice(:language, :location, :work_mode, :salary_min, :salary_max, :currency, :description, :published_at)
                 .compact.merge(title: attrs[:title])
          )
      end
    end
  end
end
