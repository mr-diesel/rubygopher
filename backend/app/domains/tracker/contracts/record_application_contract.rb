module Tracker
  module Contracts
    class RecordApplicationContract < Dry::Validation::Contract
      params do
        required(:company_name).filled(Tracker::Types::StrippedString)
        required(:vacancy_title).filled(Tracker::Types::StrippedString)
        optional(:apply_url).maybe(:string)
        optional(:applied_at).maybe(:time)
        optional(:language).maybe(:string, included_in?: Vacancy.languages.keys)
        optional(:work_mode).maybe(:string, included_in?: Vacancy.work_modes.keys)
        optional(:location).maybe(:string)
        optional(:comment).maybe(:string)
        optional(:next_follow_up_at).maybe(:time)
      end

      rule(:apply_url) do
        key.failure("must be an http(s) URL") if value && !value.match?(%r{\Ahttps?://\S+\z})
      end
    end
  end
end
