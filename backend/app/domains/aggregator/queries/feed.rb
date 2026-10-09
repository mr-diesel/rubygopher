module Aggregator
  module Queries
    # The vacancy feed: aggregated postings only (manual tracker vacancies are not
    # news), newest first, with the user's own marks: seen and applied.
    class Feed
      PER_PAGE = 30
      FILTERS = %i[language work_mode source only_new q].freeze

      Page = Struct.new(:vacancies, :total, :page, :per_page, keyword_init: true)

      def initialize(user, page: 1, **filters)
        @user = user
        @filters = filters.slice(*FILTERS)
        @page = [ page.to_i, 1 ].max
      end

      def call
        scope = filtered(base)
        total = scope.count
        vacancies = scope.includes(:company, :postings).order(Arel.sql("COALESCE(vacancies.published_at, vacancies.created_at) DESC"), id: :desc)
                         .offset((@page - 1) * PER_PAGE).limit(PER_PAGE).to_a
        decorate(vacancies)
        Page.new(vacancies: vacancies, total: total, page: @page, per_page: PER_PAGE)
      end

      private

      def base
        Vacancy.where(id: VacancyPosting.active.where.not(source: :manual).select(:vacancy_id))
      end

      def filtered(scope)
        scope = scope.where(language: @filters[:language]) if @filters[:language].present?
        scope = scope.where(work_mode: @filters[:work_mode]) if @filters[:work_mode].present?
        scope = scope.where(id: VacancyPosting.where(source: @filters[:source]).select(:vacancy_id)) if @filters[:source].present?
        scope = scope.where(created_at: seen_since..) if @filters[:only_new]
        scope = scope.where("vacancies.title ILIKE :q OR vacancies.description ILIKE :q", q: "%#{Vacancy.sanitize_sql_like(@filters[:q])}%") if @filters[:q].present?
        scope
      end

      def seen_since
        @user.vacancies_seen_at || @user.created_at
      end

      # Two per-user marks attached to the loaded rows, without a query per row.
      def decorate(vacancies)
        applied = @user.job_applications.where(vacancy_id: vacancies.map(&:id)).pluck(:vacancy_id, :id).to_h
        vacancies.each do |vacancy|
          vacancy.new_for_user = vacancy.created_at > seen_since
          vacancy.application_id = applied[vacancy.id]
        end
      end
    end
  end
end
