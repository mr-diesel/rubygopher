module Playground
  module API
    class Console < Grape::API
      helpers Identity::API::AuthHelpers

      before { authenticate! }

      resource :console do
        params do
          requires :code, type: String, allow_blank: false
          optional :context, type: String, values: Playground::Runner::CONTEXTS, default: "rails"
          optional :timeout, type: Integer, values: 1..30, default: Playground::Runner::DEFAULT_TIMEOUT
        end
        post :eval do
          error!({ error: "console is disabled in this environment" }, 403) unless Playground::Runner.enabled?

          Playground::Runner.call(
            code: params[:code],
            context: params[:context],
            timeout: params[:timeout]
          )
        end
      end
    end
  end
end
