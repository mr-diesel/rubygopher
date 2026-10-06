module Agent
  module API
    class Base < Grape::API
      format :json
      content_type :txt, "text/plain"

      mount Agent::API::Docs
    end
  end
end
