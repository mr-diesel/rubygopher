module Tracker
  module API
    class Digest < Grape::API
      helpers Identity::API::AuthHelpers

      before { authenticate! }

      resource :digest do
        get do
          digest = Queries::Digest.new(current_user)
          {
            follow_ups: {
              due: Entities::Application.represent(digest.follow_ups_due.to_a),
              upcoming: Entities::Application.represent(digest.follow_ups_upcoming.to_a)
            },
            new_vacancies: { count: digest.new_vacancies_count, since: digest.new_vacancies_since }
          }
        end

        post :vacancies_seen do
          current_user.update!(vacancies_seen_at: Time.current)
          status 204
          body false
        end
      end
    end
  end
end
