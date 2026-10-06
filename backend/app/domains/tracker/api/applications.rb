module Tracker
  module API
    class Applications < Grape::API
      helpers Identity::API::AuthHelpers, Tracker::API::Helpers

      before { authenticate! }

      resource :applications do
        params do
          optional :status, type: String, values: JobApplication.statuses.keys
          optional :archived, type: Boolean, default: false
        end
        get do
          scope = current_user.job_applications.includes(:company, :vacancy, :via_posting).order(last_activity_at: :desc, id: :desc)
          scope = params[:archived] ? scope.archived : scope.active
          scope = scope.where(status: params[:status]) if params[:status]
          present scope.to_a, with: Entities::Application
        end

        params do
          optional :url, type: String, desc: "vacancy link; hh.ru, career.habr.com and getmatch.ru links resolve the vacancy by themselves"
          optional :company_name, type: String
          optional :vacancy_title, type: String
          optional :applied_at, type: DateTime
          optional :language, type: String, values: Vacancy.languages.keys
          optional :work_mode, type: String, values: Vacancy.work_modes.keys
          optional :location, type: String
          optional :comment, type: String
          optional :next_follow_up_at, type: DateTime
        end
        post do
          result = Operations::RecordApplication.new.call(current_user, input)
          fail!(result.failure) if result.failure?

          status 201
          present result.value!, with: Entities::Application, full: true
        end

        route_param :id, type: Integer do
          get do
            application = current_user.job_applications.includes(:company, :vacancy, :via_posting, :events).find_by(id: params[:id])
            fail!([ :not_found ]) unless application

            present application, with: Entities::Application, full: true
          end

          params do
            requires :event_type, type: String, values: JobApplicationEvent.event_types.keys
            optional :status, type: String, values: JobApplication.statuses.keys
            optional :comment, type: String
            optional :occurred_at, type: DateTime
            optional :next_follow_up_at, type: DateTime
          end
          post :events do
            result = Operations::AddEvent.new.call(current_user, params[:id], input)
            fail!(result.failure) if result.failure?

            status 201
            present result.value!, with: Entities::Event
          end
        end
      end
    end
  end
end
