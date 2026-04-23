class MainwareController < ApplicationController
  include Pagy::Backend

  def index
    @itemz =  Item.all
    @pagy, @itemz = pagy(@itemz)

  end

  def search
  end

  def searchqr
  end
end
