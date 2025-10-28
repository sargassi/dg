# app/controllers/api/v1/base_controller.rb
class Api::V1::BaseController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

  before_action :authenticate

  attr_reader :current_user

  private

  def authenticate
    authenticate_user_with_token || handle_bad_authentication
  end

  def authenticate_user_with_token
    authenticate_with_http_token do |token, options|
      current_api_token = ApiToken.where(active: true).find_by_token(token)
      @current_user = current_api_token&.user
    end
  end

  def handle_bad_authentication
    render json: { message: "Credenziali errate" }, status: :unauthorized
  end

  def handle_not_found
    render json: { message: "Record non trovato" }, status: :not_found
  end
end
