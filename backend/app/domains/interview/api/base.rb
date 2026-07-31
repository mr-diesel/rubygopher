module Interview
  module API
    class Base < Grape::API
      format :json

      rescue_from ActiveRecord::RecordNotFound do
        error!({ error: "not found" }, 404)
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        error!({ errors: e.record.errors.to_hash }, 422)
      end

      mount Interview::API::Questions
    end
  end
end
