module Playground
  module Operations
    class PurgeStaleSessions < Dry::Operation
      def call
        ConsoleSession.stale.delete_all
      end
    end
  end
end
