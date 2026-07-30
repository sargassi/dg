module Admin
  class DashboardController < ApplicationController
    before_action :require_godlike!

    def index
      @users_count = User.count
      @toolbar_configs_count = ToolbarConfig.count
    end
  end
end
