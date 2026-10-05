module Playground
  module API
    class Console < Grape::API
      helpers Identity::API::AuthHelpers

      before { authenticate! }

      resource :console do
        params do
          requires :code, type: String, allow_blank: false, length: { max: Playground::Runner::MAX_CODE_LENGTH }
          optional :context, type: String, values: Playground::Runner::CONTEXTS, default: "rails"
          optional :timeout, type: Integer, values: 1..30, default: Playground::Runner::DEFAULT_TIMEOUT
        end
        post :eval do
          error!({ error: "console is disabled in this environment" }, 403) unless Playground::Runner.enabled?
          verdict = Playground::RateLimit.consume(current_user)
          unless verdict.allowed?
            header "Retry-After", verdict.retry_after.ceil.to_s
            error!({ error: "too many requests, retry in #{verdict.retry_after.ceil}s" }, 429)
          end

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
