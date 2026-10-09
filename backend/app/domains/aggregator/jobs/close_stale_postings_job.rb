module Aggregator
  module Jobs
    class CloseStalePostingsJob < ApplicationJob
      queue_as :low

      def perform
        Operations::CloseStalePostings.new.call
      end
    end
  end
end
