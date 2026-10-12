module Identity
  module API
    class Profile < Grape::API
      helpers AuthHelpers

      helpers do
        def profile
          current_user.slice(:email, :name, :resume)
        end
      end

      resource :me do
        desc "The user's profile: name and résumé text (the résumé feeds the mock-interview prompt)"
        get do
          authenticate!
          profile
        end

        desc "Update the profile; send the résumé as plain text or Markdown"
        params do
          optional :name, type: String
          optional :resume, type: String, desc: "up to 20 000 characters; null clears it"
        end
        patch do
          authenticate!
          result = Operations::UpdateProfile.new.call(current_user, declared(params, include_missing: false).to_h)
          error!({ errors: result.failure.last }, 422) if result.failure?
          profile
        end
      end
    end
  end
end
