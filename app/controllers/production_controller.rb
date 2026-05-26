class ProductionController < ApplicationController

  include Pagy::Backend

  def dashboard
    @latest_proformas = Proforma.open.includes(prows: :tempestas).order(id: :desc).limit(5)
  end

  def research
    @profs = Proforma.open.select(:id, :customer, :data_in)
    prof_ids = @profs.map(&:id)
    @q = if params[:customer].present? && params[:customer] != ''
      Prow.where(proforma_id: params[:customer]).ransack(params[:q])
    else
      Prow.where(proforma_id: prof_ids).ransack(params[:q])
    end
    @rows = @q.result(distinct: true).includes(:proforma)
    items = params[:customer].present? ? [@rows.count(:all), 1].max : 25
    @pagy, @rows = pagy(@rows, items: items)
  end

  def research_qr
    prof_ids = Proforma.open.pluck(:id)
    @q = Prow.where(proforma_id: prof_ids, closed: false).ransack(params[:q])
    @rows = @q.result(distinct: true)
    @pagy, @rows = pagy(@rows)
  end

  def checkpoint_single
    @sez = params[:place]
    prof_ids = Proforma.open.pluck(:id)
    @q = Prow.where(proforma_id: prof_ids, closed: false).ransack(params[:q])
    @rows = @q.result(distinct: true)
  end

  def checkpoint
    src = params[:src]
    dom = params[:q][:qr_eq] if params[:q].present?
    tmp = params[:tid]
    prow_id = params[:prow].to_i
    stage = params[:stage]
    datex = params[:date]

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
    end

    if chk.save
      hasDoneTempestas?(prow_id) && setProwDone(prow_id, datex)

      respond_to do |format|
        format.html do
          redirect_to case src
          when 'search'
            production_research_qr_path(q: dom)
          when 'list', 'searchplain'
            prow_path(prow_id, proforma: Prow.find(prow_id).proforma_id, src: src)
          end
        end
      end
    end
  end

end
