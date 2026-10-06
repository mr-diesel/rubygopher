module Tracker
  module Queries
    # What needs the user's attention right now: follow-ups that are due and
    # vacancies that appeared in the feed since they last looked.
    class Digest
      UPCOMING_WINDOW = 7.days

      def initialize(user, now: Time.current)
        @user = user
        @now = now
      end

      def follow_ups_due
        @user.job_applications.follow_up_due(@now).includes(:company, :vacancy).order(:next_follow_up_at)
      end

      def follow_ups_upcoming
        @user.job_applications.active.includes(:company, :vacancy)
             .where(next_follow_up_at: @now..(@now + UPCOMING_WINDOW)).order(:next_follow_up_at)
      end

      def new_vacancies_since
        @user.vacancies_seen_at || @user.created_at
      end

      def new_vacancies_count
        Vacancy.joins(:postings).where.not(vacancy_postings: { source: :manual })
               .where(vacancies: { created_at: new_vacancies_since.. }).distinct.count
      end
    end
  end
end
