class UtilitiesController < ApplicationController

  def dashboard

  end

  def etichette
    @products_import = ProductsImport.new
    @etigroup = Product.all.order('created_at DESC').group_by { |product| product.group }
  end

  def etichette_lab
   if params[:etid].present? && params[:etid] != ''
     @etigroup =  Etilab.where('id = ?', params[:etid]).order('created_at DESC').group_by {|x| x.group }

   elsif params[:group].present? && params[:group] != ''
       @etigroup = Etilab.where('ragg = ?', params[:group]).order('created_at DESC').group_by { |x| x.group }
    else
       @etigroup = Etilab.all.order('created_at DESC').group_by { |x| x.group }
    end

    @search = Etilab.all.order('created_at DESC').limit(400).group_by { |x| x.group }
  end

  def etichette_camp
    @etigroup = if params[:etid].present? && params[:etid] != ''
      Eticamp.where('id = ?', params[:etid]).order('created_at DESC').group_by { |x| x.group }
    else
      Eticamp.all.order('created_at DESC').group_by { |x| x.group }
    end

    @search = Eticamp.all.order('created_at DESC').limit(400).group_by { |x| x.group }
  end

  def etichette_gen
    @working_date = Date.current
    @group = Etigen.last.present? ? Etigen.last.group.to_i + 1 : 1
    @etigroup = if params[:etgen].present? && params[:etigen] != ''
                  Etigen.where('group = ?', params[:group]).order('created_at DESC').group_by { |x| x.group }
                else
                  Etigen.all.order('created_at DESC').group_by { |x| x.group }
                end
    return unless @etigroup.present?

    @singtot = @etigroup.first[1].size
  end

  def etilgenimp
    if params[:etigen].present? and params[:etigen] == 'y'
      gen = CreateCanvasPagesService.new
      gen.init(params[:pages], params[:dategroup], params[:group])
    end
    respond_to do |format|
      format.html { redirect_to utilities_etichette_gen_path(etigen: 'y', group: params[:group]), notice: 'Ok.' }
      format.json { head :no_content }
    end
  end

  def eticampimp
    if params[:import].present? and params[:import] == 'y'
      import = ImportEticampService.new
      import.call(params[:file], params[:season])
    end
    respond_to do |format|
      format.html { redirect_to utilities_etichette_camp_path, notice: 'Importate.' }
      format.json { head :no_content }
    end
  end

  def etilabimp
    if params[:import].present? and params[:import] == 'y'
      import = ImportEtilabService.new
      import.call(params[:file])
    end
    respond_to do |format|
      format.html { redirect_to utilities_etichette_lab_path, notice: 'Importate.' }
      format.json { head :no_content }
    end
  end

  def eticampione
    @working_date = Date.current

  end

end
