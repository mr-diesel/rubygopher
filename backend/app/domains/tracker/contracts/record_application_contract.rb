module Tracker
  module Contracts
    class RecordApplicationContract < Dry::Validation::Contract
      params do
        optional(:url).maybe(:string)
        optional(:company_name).maybe(Tracker::Types::StrippedString)
        optional(:vacancy_title).maybe(Tracker::Types::StrippedString)
        optional(:applied_at).maybe(:time)
        optional(:language).maybe(:string, included_in?: Vacancy.languages.keys)
        optional(:work_mode).maybe(:string, included_in?: Vacancy.work_modes.keys)
        optional(:location).maybe(:string)
        optional(:comment).maybe(:string)
        optional(:next_follow_up_at).maybe(:time)
      end

      rule(:url) do
        key.failure("must be an http(s) URL") if value && !value.match?(%r{\Ahttps?://\S+\z})
      end

      rule(:url, :company_name, :vacancy_title) do
        if values[:url].blank? && (values[:company_name].blank? || values[:vacancy_title].blank?)
          base.failure("give the vacancy url, or company_name and vacancy_title")
        end
      end
    end
  end
end
