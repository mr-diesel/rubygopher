module Aggregator
  module Jobs
    class ExtractSkillsJob < ApplicationJob
      queue_as :low

      def perform
        Operations::ExtractPendingSkills.new.call
      end
    end
  end
end
