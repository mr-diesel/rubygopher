module Tracker
  module Jobs
    class FollowUpRemindersJob < ApplicationJob
      queue_as :critical

      def perform
        Operations::RemindFollowUps.new.call
      end
    end
  end
end
