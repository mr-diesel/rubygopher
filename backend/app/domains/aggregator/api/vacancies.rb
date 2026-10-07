module Aggregator
  module API
    class Vacancies < Grape::API
      helpers Identity::API::AuthHelpers

      before { authenticate! }

      desc "Aggregated vacancy feed, newest first, with 'new since you last looked' and 'already applied' marks"
      params do
        optional :language, type: String, values: ::Vacancy.languages.keys
        optional :work_mode, type: String, values: ::Vacancy.work_modes.keys
        optional :source, type: String, values: VacancyPosting.sources.keys - [ "manual" ]
        optional :only_new, type: Boolean, default: false
        optional :q, type: String, desc: "substring of the title or description"
        optional :page, type: Integer, default: 1
      end
      get :vacancies do
        filters = declared(params, include_missing: false).to_h.except("page").symbolize_keys
        page = Queries::Feed.new(current_user, page: params[:page], **filters).call
        { vacancies: Entities::Vacancy.represent(page.vacancies), total: page.total, page: page.page, per_page: page.per_page }
      end
    end
  end
end
