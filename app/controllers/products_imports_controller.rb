class ProductsImportsController < ApplicationController
  def new
    @products_import = ProductsImport.new
  end

  def create
    begin
    @products_import = ProductsImport.new(params[:products_import])
    rescue => e
      puts e.inspect
    end
    if @products_import.save
      redirect_to utilities_etichette_path
    else
      render :new
    end
  end
end
