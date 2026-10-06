module Aggregator
  module Consumers
    class RawPostingsConsumer < ApplicationConsumer
      def consume
        messages.each do |message|
          result = Operations::IngestPosting.new.call(message.payload)
          Karafka.logger.warn("vacancies.raw: skipped #{message.key.inspect}: #{result.failure.last}") if result.failure?
          mark_as_consumed(message)
        end
      end
    end
  end
end
