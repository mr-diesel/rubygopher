module Tracker
  module API
    class Outreaches < Grape::API
      helpers Identity::API::AuthHelpers, Tracker::API::Helpers

      before { authenticate! }

      resource :outreaches do
        desc "List cold outreach, newest first"
        params do
          optional :status, type: String, values: CompanyOutreach.statuses.keys
        end
        get do
          scope = current_user.company_outreaches.includes(:company).order(sent_at: :desc, id: :desc)
          scope = scope.where(status: params[:status]) if params[:status]
          present scope.to_a, with: Entities::Outreach
        end

        desc "Record a cold email or message to a company"
        params do
          requires :company_name, type: String
          optional :sent_at, type: DateTime
          optional :notes, type: String
        end
        post do
          result = Operations::RecordOutreach.new.call(current_user, input)
          fail!(result.failure) if result.failure?

          status 201
          present result.value!, with: Entities::Outreach, full: true
        end

        route_param :id, type: Integer do
          desc "One outreach with its status history"
          get do
            outreach = current_user.company_outreaches.includes(:company, :events).find_by(id: params[:id])
            fail!([ :not_found ]) unless outreach

            present outreach, with: Entities::Outreach, full: true
          end

          desc "Change the outreach status"
          params do
            requires :status, type: String, values: CompanyOutreach.statuses.keys
            optional :comment, type: String
            optional :changed_at, type: DateTime
          end
          post :status do
            result = Operations::ChangeOutreachStatus.new.call(current_user, params[:id], input)
            fail!(result.failure) if result.failure?

            status 201
            present result.value!, with: Entities::OutreachEvent
          end
        end
      end
    end
  end
end
