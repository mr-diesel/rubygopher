module AdminArea
  # Namespaced AdminArea (not Admin) to avoid clashing with the Admin model.
  class ApplicationController < ::ApplicationController
    before_action :authenticate_admin!
    layout "admin"
  end
end
