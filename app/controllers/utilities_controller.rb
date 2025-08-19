class UtilitiesController < ApplicationController
  def etichette

    @products_import = ProductsImport.new
    @etigroup = Product.all.order('created_at DESC').group_by{|product| product.group}

  end
end
