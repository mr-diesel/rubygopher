module Tracker
  module Contracts
    class AddEventContract < Dry::Validation::Contract
      params do
        required(:event_type).filled(:string, included_in?: JobApplicationEvent.event_types.keys)
        optional(:status).maybe(:string, included_in?: JobApplication.statuses.keys)
        optional(:comment).maybe(:string)
        optional(:occurred_at).maybe(:time)
        optional(:next_follow_up_at).maybe(:time)
      end

      rule(:status, :event_type) do
        key(:status).failure("is required for status_changed") if values[:event_type] == "status_changed" && values[:status].nil?
      end
    end
  end
end
