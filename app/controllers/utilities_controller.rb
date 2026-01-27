class UtilitiesController < ApplicationController


  def etichette

    @products_import = ProductsImport.new
    @etigroup = Product.all.order('created_at DESC').group_by{|product| product.group}

  end

  def etichette_lab
    if params[:etid].present? && params[:etid] != ''
      @etigroup = Etilab.where('id = ?', params[:etid]).order('created_at DESC').group_by{|x| x.group}

    else
      @etigroup = Etilab.all.order('created_at DESC').group_by{|x| x.group}
    end

  end

  def etichette_gen

    @working_date = Date.current
    Etigen.last.present? ? @group = Etigen.last.group.to_i + 1 : @group = 1
    if params[:etgen].present? && params[:etigen] != ''

      @etigroup = Etigen.where('group = ?', params[:group]).order('created_at DESC').group_by{|x| x.group}
    else
      @etigroup = Etigen.all.order('created_at DESC').group_by{|x| x.group}
    end

    @singtot = @etigroup.first[1].size
  end

  def etilgenimp
    if params[:etigen].present? and params[:etigen] == 'y'
      gen = CreateCanvasPagesService.new
      gen.init(params[:pages], params[:dategroup], params[:group] )
    end
    respond_to do |format|
      format.html { redirect_to utilities_etichette_gen_path(:etigen => 'y', :group => params[:group]), notice: "Ok." }
      format.json { head :no_content }
    end
  end


  def etilabimp
    if params[:import].present? and params[:import] == 'y'
      import = ImportEtilabService.new
      import.call(params[:file])
    end
    respond_to do |format|
      format.html { redirect_to utilities_etichette_lab_path, notice: "Importate." }
      format.json { head :no_content }
    end
  end
end
