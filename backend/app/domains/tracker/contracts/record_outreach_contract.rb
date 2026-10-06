module Tracker
  module Contracts
    class RecordOutreachContract < Dry::Validation::Contract
      params do
        required(:company_name).filled(Tracker::Types::StrippedString)
        optional(:sent_at).maybe(:time)
        optional(:notes).maybe(:string)
      end
    end
  end
end
