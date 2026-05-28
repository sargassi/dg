# app/controllers/basic_qr_codes_controller.rb

class BasicQrCodesController < ApplicationController
  before_action -> { require_ability!('manage_basic_qr_codes') }

  def index
  end

  def qrcheck
    string = params[:key]
    render json: 'ok'
  end
end
