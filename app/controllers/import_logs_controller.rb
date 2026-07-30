class ImportLogsController < ApplicationController
  before_action -> { require_ability!('manage_mainware') }

  def index
    @import_logs = ImportLog.includes(:user).order(created_at: :desc)
  end

  def show
    @import_log = ImportLog.find(params[:id])
  end
end
