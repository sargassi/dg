# app/controllers/basic_qr_codes_controller.rb

class BasicQrCodesController < ApplicationController
  def index
  end

  def qrcheck
    string = params[:key]
    render json: 'ok'
  end
end
