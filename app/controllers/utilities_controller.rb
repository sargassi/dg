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
