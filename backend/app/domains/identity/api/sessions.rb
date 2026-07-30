module Identity
  module API
    class Sessions < Grape::API
      helpers AuthHelpers

      params do
        requires :email, type: String
        requires :password, type: String
      end
      post :login do
        user = User.find_by(email: params[:email])
        error!({ error: "invalid email or password" }, 401) unless user&.valid_password?(params[:password])

        token, = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
        status 200
        { token: token, user: { id: user.id, email: user.email, name: user.name } }
      end

      delete :logout do
        authenticate!
        User.revoke_jwt(nil, current_user)
        status 204
      end
    end
  end
end
