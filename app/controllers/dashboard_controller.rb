class DashboardController < ApplicationController
  before_action :redirect_pedone, only: [:index, :home]

  def index
    @portal_counts = portal_counts if current_user.godlike?
  end

  def home
  end

  private

  def portal_counts
    {
      items: Item.count,
      itemouts: Itemout.count,
      movements_today: Itemmovement.where(created_at: Time.zone.today.all_day).count,
      active_proformas: Proforma.where(closed: [false, nil]).count
    }
  end

  def redirect_pedone
    if current_user.has_role?(:pedone)
      redirect_to app_dashboard_path
    end
  end
end
