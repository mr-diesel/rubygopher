module Playground
  module Jobs
    class PurgeConsoleSessionsJob < ApplicationJob
      queue_as :low

      def perform
        Operations::PurgeStaleSessions.new.call
      end
    end
  end
end
