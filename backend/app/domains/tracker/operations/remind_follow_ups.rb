module Tracker
  module Operations
    # One reminder per follow-up date: an application is picked while its
    # next_follow_up_at is due and newer than the last reminder, so rerunning the
    # job never repeats a reminder and a new date starts a new cycle.
    class RemindFollowUps < Dry::Operation
      def call(now: Time.current)
        due = JobApplication.follow_up_due(now)
                            .where("follow_up_reminded_at IS NULL OR follow_up_reminded_at < next_follow_up_at")
                            .includes(:user, :company, :vacancy)
        reminded = 0
        due.find_each do |application|
          application.transaction do
            application.update!(follow_up_reminded_at: now)
            Events.follow_up_due(application)
          end
          reminded += 1
        end
        reminded
      end
    end
  end
end
