# class Api::V1::HomeController < Api::V1::BaseController
class Api::V1::HomeController < ActionController::Base
  def index
    render json: { message: "hi there noddy" }
  end

  def list_qrs
    @prows = Prow.where('done = false')
    render json: @prows
  end

end
