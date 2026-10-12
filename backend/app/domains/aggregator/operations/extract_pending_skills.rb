module Aggregator
  module Operations
    # Backfill: vacancies never scanned, or reset by nulling skills_extracted_at after a
    # dictionary change. Returns how many were processed.
    class ExtractPendingSkills < Dry::Operation
      def call(limit: 500)
        matcher = SkillMatcher.new
        pending = Vacancy.skills_pending.includes(:postings).limit(limit).to_a
        pending.each { |vacancy| ExtractSkills.new(matcher: matcher).call(vacancy) }
        pending.size
      end
    end
  end
end
