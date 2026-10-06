module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = Identity::Authenticate.call(request.params[:token]) || reject_unauthorized_connection
    end
  end
end
