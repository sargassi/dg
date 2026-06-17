class DashboardController < ApplicationController
  before_action :redirect_pedone, only: [:index, :home]

  def index
  end

  def home
  end

  private

  def redirect_pedone
    if current_user.has_role?(:pedone)
      redirect_to app_dashboard_path
    end
  end
end
