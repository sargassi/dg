class AppController < ApplicationController
  def dashboard
    @sections = ['F1', 'F2', 'F3', 'F4', 'F5']
  end

  def sez

    params[:place].present? ? sector = params[:place] : sector = ''
    @title = "Sez #{sector}"
    @sections = ['F1', 'F2', 'F3', 'F4', 'F5']

    profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact

    @sez = params[:place]

    @q = Prow.where('proforma_id in (?) and closed is false', profs).ransack(params[:q])
    @rows = @q.result(distinct: true)

  end
end
