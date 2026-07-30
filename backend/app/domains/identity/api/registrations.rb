module Identity
  module API
    class Registrations < Grape::API
      params do
        requires :email, type: String
        requires :password, type: String
        optional :name, type: String
      end
      post :signup do
        result = Operations::SignUp.new.call(params.to_h.symbolize_keys)

        if result.success?
          user, token = result.value!.values_at(:user, :token)
          status 201
          { token: token, user: { id: user.id, email: user.email, name: user.name } }
        else
          error!({ errors: result.failure }, 422)
        end
      end
    end
  end
end
