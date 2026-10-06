module Identity
  module API
    class ApiTokens < Grape::API
      helpers AuthHelpers

      helpers do
        def token_status
          {
            token: current_user.api_token,
            generated_at: current_user.api_token_generated_at,
            last_used_at: current_user.api_token_last_used_at
          }
        end
      end

      resource "me/api_token" do
        desc "Show the personal API token for external assistants"
        get do
          require_session!
          token_status
        end

        desc "Issue a new token; the previous one stops working immediately"
        post do
          require_session!
          current_user.regenerate_api_token!
          status 201
          token_status
        end

        desc "Revoke the token"
        delete do
          require_session!
          current_user.revoke_api_token!
          status 204
          body false
        end
      end
    end
  end
end
