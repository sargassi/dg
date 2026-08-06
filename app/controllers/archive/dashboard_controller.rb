module Archive
  class DashboardController < ApplicationController
    before_action -> { require_ability!('manage_archive') }

    def index
      @total_items = Archive::Item.count
      @in_stock = Archive::Item.in_stock.count
      @checked_out = Archive::Item.checked_out.count

      @categories = Archive::Category.order(:name)
      @locations = Archive::Location.sectors.order(:code)

      @latest_checkouts = Archive::Transaction.includes(:item, :operator)
                                               .where(action: "checkout")
                                               .order(date: :desc, created_at: :desc)
                                               .limit(5)
      @latest_checkins = Archive::Transaction.includes(:item, :operator)
                                              .where(action: "checkin")
                                              .order(date: :desc, created_at: :desc)
                                              .limit(5)
    end
  end
end
