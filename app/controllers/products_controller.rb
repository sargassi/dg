class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]
  # GET /products or /products.json


  # GET /products/1 or /products/1.json
  def show
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: [@product.id, @product.decsription].join('-'),
        template: "products/show.html.erb",
        formats: [:html],
        disposition: :attachment,
        layout: 'pdf'
      end
    end
  end

  def etichette
    @products = Product.all.order('created_at DESC').group_by{|product| product.group}
    #@products = Product.all.group_by{|product| product.created_at.to_s}
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: @products.count.to_s,
        orientation: 'Portrait',
        formats: [:html],
        disposition: :inline,
        layout: 'pdf',
        page_size: 'A4',
        default_header: false,
        lowquality:      false,
        page_height:     297,
        page_width:      210,
        #disable_smart_shrinking: false,
        margin:  {   top:    4,                     # default 10 (mm)
          bottom:            4,
          left:              0,
          right:             0 }
      end
    end
  end

  # GET /products/new
  def new
    @product = Product.new
  end

  # GET /products/1/edit
  def edit
  end

  def index
    @products = Product.all.group_by{|product| product.created_at.to_s}
    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "Posts: #{@products.count}",
        orientation: 'Landscape',
        formats: [:html],
        disposition: :inline,
        layout: 'pdf'
      end
    end
  end



  # POST /products or /products.json
  def create
    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to product_url(@product), notice: "Product was successfully created." }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /products/1 or /products/1.json
  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to product_url(@product), notice: "Product was successfully updated." }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1 or /products/1.json
  def destroy
    @product.destroy

    respond_to do |format|
      format.html { redirect_to products_url, notice: "Product was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product
      @product = Product.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def product_params
      params.require(:product).permit(:prodcode, :itemcode, :fabricode, :varcode, :description, :tg, :note, :fabric, :color, :materiale, :costo)
    end

    private
    def set_prodcode

    end
end
