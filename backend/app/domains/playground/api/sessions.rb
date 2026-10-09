module Playground
  module API
    class Sessions < Grape::API
      helpers Identity::API::AuthHelpers

      before { authenticate! }

      resource "console/sessions" do
        params do
          optional :code, type: String, default: ""
          optional :context, type: String, values: Playground::Runner::CONTEXTS, default: "rails"
        end
        post do
          session = ConsoleSession.create!(declared(params).to_h)
          status 201
          session.state
        end

        route_param :token, type: String do
          get do
            session = ConsoleSession.active.find_by(token: params[:token])
            error!({ error: "session not found" }, 404) unless session

            session.state
          end
        end
      end
    end
  end
end
