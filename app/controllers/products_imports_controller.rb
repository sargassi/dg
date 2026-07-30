class ProductsImportsController < ApplicationController
  before_action -> { require_ability!('manage_products_imports') }

  def new
    @products_import = ProductsImport.new
  end

  def create
    @products_import = ProductsImport.new(products_import_params)
    if @products_import.save
      redirect_to utilities_etichette_path
    else
      render :new
    end
  end

  private

  def products_import_params
    params.require(:products_import).permit(:file)
  end
end
