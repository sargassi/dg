class ProductionController < ApplicationController

  include Pagy::Backend

  def research
    @profs = Proforma.where('closed is not true').order('created_at desc')
    profs = @profs.select(:id).map(&:id).compact
    if params[:customer].present? and params[:customer] != ''
      @q = Prow.where('proforma_id = ?', params[:customer]).ransack(params[:q])
    else
      @q = Prow.where('proforma_id in (?)', profs).ransack(params[:q])
    end
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

  def checkpoint_single
    place = params[:place]
    profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact
      @sez = params[:place]

      @q = Prow.where('proforma_id in (?) and closed is false', profs).ransack(params[:q])
      @rows = @q.result(distinct: true)

  end

  def checkpoint
    src = params[:src]
    dom = params[:q][:qr_eq] if params[:q].present?
    tmp = params[:tid]
    prow = params[:prow]
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
     if hasDoneTempestas?(prow.to_i)
       setProwDone(prow.to_i, datex )
     end

    respond_to do |format|
      format.html do
        if src = 'scan'
          redirect_to app_check_qr_path(:sector => stage, :q => dom)
        if src == 'search'
          redirect_to production_research_qr_path(q: dom)
        elsif src == 'list'
          redirect_to prow_path(prow.to_i, :proforma => Prow.find(prow.to_i).proforma_id, :src => src )
        #redirect_to proforma_path(Prow.find(tmp.to_i).proforma_id)
        elsif src == 'searchplain'
          redirect_to prow_path(prow.to_i, :proforma => Prow.find(prow.to_i).proforma_id, :src => src )
        end
      end
    end
end
  end

end
