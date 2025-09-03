class EtilabsController < ApplicationController
  before_action :set_etilab, only: %i[ show edit update destroy ]

  # GET /etilabs or /etilabs.json
  def index
    @etilabs = Etilab.all
  end

  # GET /etilabs/1 or /etilabs/1.json
  def show
  end

  # GET /etilabs/new
  def new
    @etilab = Etilab.new
  end

  # GET /etilabs/1/edit
  def edit
  end

  def import

  end

  # POST /etilabs or /etilabs.json
  def create
    @etilab = Etilab.new(etilab_params)

    respond_to do |format|
      if @etilab.save
        format.html { redirect_to utilities_etichette_path(:id => @etilab.id), notice: "Creato." }
        format.json { render :show, status: :created, location: @etilab }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @etilab.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /etilabs/1 or /etilabs/1.json
  def update
    respond_to do |format|
      if @etilab.update(etilab_params)
        format.html { redirect_to utilities_etichette_lab_path(:etid => @etilab.id), notice: "Aggiornato." }
        format.json { render :show, status: :ok, location: @etilab }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @etilab.errors, status: :unprocessable_entity }
      end
    end
  end

  def etichette
    @products = Etilab.all.order('created_at DESC').group_by{|product| product.group}
    #@products = Product.all.group_by{|product| product.created_at.to_s}
    respond_to do |format|

    format.html
    format.pdf do
      render :pdf => @products.count.to_s , orientation: "portrait",page_size: 'A4',margin:  {top:'0mm',bottom: '0m',left: '0mm',right:'0mm' }, disable_smart_shrinking: true, show_as_html: params.key?('debug')

    end
    end
  end

  # DELETE /etilabs/1 or /etilabs/1.json
  def destroy
    @etilab.destroy

    respond_to do |format|
      format.html { redirect_to etilabs_url, notice: "Etilab was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_etilab
      @etilab = Etilab.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def etilab_params
      params.require(:etilab).permit(:itemcode, :fabricode, :varcode, :description, :tg, :color, :qty, :materiale, :group, :customer, :supplier, :note, :fabric)
    end
end
