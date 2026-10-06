module Playground
  module Jobs
    # Enqueued whenever a session is created, so the table trims itself without a scheduler.
    class PurgeConsoleSessionsJob < ApplicationJob
      queue_as :low

      def perform
        Operations::PurgeStaleSessions.new.call
      end
    end
  end
end
