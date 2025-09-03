class ProductionController < ApplicationController

  include Pagy::Backend

  def research
    profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact
    @q = Prow.where('proforma_id in (?)', profs).ransack(params[:q])
    @rows = @q.result(distinct: true)
    @pagy, @rows = pagy(@rows)
  end

  def research_qr
    profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact
    @q = Prow.where('proforma_id in (?) and closed is false', profs).ransack(params[:q])
    @rows = @q.result(distinct: true)
    @pagy, @rows = pagy(@rows)

    if params[:xxx].present?

    end
  end

  def checkpoint
    dom = params[:q][:qr_eq]
    tmp = params[:tid]
    stage = params[:stage]
    datex = params[:date]
    target = params[:target]
    #cerca singola tempesta &&set true
    chk = Tempesta.find(tmp)
    case stage
      when "F1"
        chk.f1 = true
        chk.f1date = datex
      when "F2"
        chk.f2 = true
        chk.f2date = datex

      when "F3"
        chk.f3 = true
        chk.f3date = datex

      when "F4"
        chk.f4 = true
        chk.f4date = datex

      when "F5"
        chk.f5 = true
        chk.f5date = datex

      else

    end
if chk.save
    respond_to do |format|
      format.html do
        redirect_to production_research_qr_path(q: dom)
      end
    end
end
  end

end
