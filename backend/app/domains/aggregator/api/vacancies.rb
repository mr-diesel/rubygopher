module Aggregator
  module API
    class Vacancies < Grape::API
      helpers Identity::API::AuthHelpers

      before { authenticate! }

      desc "Skills dictionary used to tag vacancies, with how many open vacancies mention each"
      get :skills do
        counts = VacancySkill.where(vacancy_id: VacancyPosting.active.where.not(source: :manual).select(:vacancy_id)).group(:skill_id).count
        ::Skill.order(:category, :name).map { |skill| Entities::Skill.represent(skill, vacancies_count: counts.fetch(skill.id, 0)) }
      end

      desc "Aggregated vacancy feed, newest first, with 'new since you last looked' and 'already applied' marks"
      params do
        optional :language, type: String, values: ::Vacancy.languages.keys
        optional :work_mode, type: String, values: ::Vacancy.work_modes.keys
        optional :source, type: String, values: VacancyPosting.sources.keys - [ "manual" ]
        optional :skill, type: String, desc: "skill slug from GET /skills, e.g. kafka"
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
