class AppController < ApplicationController

  ALLOWED_SECTORS = ['f1', 'f2', 'f3', 'f4', 'f5'].freeze


  def dashboard
    @sections = ALLOWED_SECTORS
  end

  def sez

    params[:place].present? ? sector = params[:place].downcase : sector = ''
    @title = "Sez #{sector}"
    @sections = ALLOWED_SECTORS

    profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact

    @sez = params[:place]

    @q = Prow.where('proforma_id in (?) and closed is false', profs).ransack(params[:q])
    @rows = @q.result(distinct: true)

  end

  def check_single_qr
    @sez = params[:place]

    # ctrl proforma aperte
    profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact

    @q = Tempesta.where("#{@sez.downcase} is null and qrcode = '#{params[:q][:qr_eq]}'").ransack(params[:q])

    @rows = @q.result(distinct: true)


  end

  def check_qr
    sector = params[:place]
    profs = Proforma.where('closed is not true').order('created_at desc').select(:id).map(&:id).compact

    @sez = params[:place]

    @q = Prow.where('proforma_id in (?) and done is false', profs).ransack(params[:q])
    @rows = @q.result(distinct: true)

    if @rows.size > 0
      datex = Date.today
      @xxx = @rows.first.tempestas.where("#{sector.downcase} = false or #{sector.downcase} is null")
      if @xxx.present?
        chk = @xxx.last
        case sector
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
          if hasDoneTempestas?(@rows.first.id.to_i)
            setProwDone(@rows.first.id.to_i, datex )
          end
          @output = chk
        end
      else
        @output = 'xxx'
      end
    end

  end


end
