module Aggregator
  module Operations
    # A posting the fetcher has not seen for a while is gone from its board.
    class CloseStalePostings < Dry::Operation
      STALE_AFTER = 7.days

      def call(now: Time.current)
        VacancyPosting.where(active: true).where.not(source: :manual).where(last_seen_at: ...(now - STALE_AFTER)).update_all(active: false, updated_at: now)
      end
    end
  end
end
