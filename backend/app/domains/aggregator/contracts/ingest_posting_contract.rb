module Aggregator
  module Contracts
    class IngestPostingContract < Dry::Validation::Contract
      params do
        required(:source).filled(:string, included_in?: VacancyPosting.sources.keys - [ "manual" ])
        required(:external_id).filled(:string)
        required(:url).filled(:string)
        required(:title).filled(Tracker::Types::StrippedString)
        required(:company).hash do
          required(:name).filled(Tracker::Types::StrippedString)
          optional(:external_id).maybe(:string)
          optional(:website).maybe(:string)
        end
        optional(:language).maybe(:string, included_in?: Vacancy.languages.keys)
        optional(:location).maybe(:string)
        optional(:work_mode).maybe(:string, included_in?: Vacancy.work_modes.keys)
        optional(:salary_min).maybe(:integer)
        optional(:salary_max).maybe(:integer)
        optional(:currency).maybe(:string)
        optional(:description).maybe(:string)
        optional(:published_at).maybe(:time)
        optional(:raw).maybe(:hash)
      end
    end
  end
end
