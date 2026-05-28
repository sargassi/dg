class StagesController < ApplicationController
  before_action -> { require_ability!('manage_stages') }

  def dashboard

  end

  def sections
    # 0 f0   start
    # 1 f1
    # 2 f2
    # 3 f3
    # 4 f4
    # 5 f5

    @section = 0
    @section = params[:section] if params[:section].present?

  end
end
