module Tracker
  module Contracts
    class ChangeOutreachStatusContract < Dry::Validation::Contract
      params do
        required(:status).filled(:string, included_in?: CompanyOutreach.statuses.keys)
        optional(:comment).maybe(:string)
        optional(:changed_at).maybe(:time)
      end
    end
  end
end
