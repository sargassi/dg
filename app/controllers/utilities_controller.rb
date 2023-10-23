class UtilitiesController < ApplicationController
  def etichette
    
    @products_import = ProductsImport.new
    @etigroup = Product.all.group_by{|product| product.created_at.to_s}
  end
end
