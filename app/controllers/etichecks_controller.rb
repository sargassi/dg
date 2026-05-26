class EtichecksController < ApplicationController
  before_action :set_eticheck, only: %i[ show edit update destroy ]

  # GET /etichecks or /etichecks.json
  def index
    @etichecks = Eticheck.all
  end

  # GET /etichecks/1 or /etichecks/1.json
  def show
  end

  # GET /etichecks/new
  def new
    @eticheck = Eticheck.new
  end

  # GET /etichecks/1/edit
  def edit
  end

  def etichette
    @products = Eticheck.all.order('created_at DESC').group_by { |product| product.group }
    # @products = Product.all.group_by{|product| product.created_at.to_s}
    respond_to do |format|
      format.pdf do
        render pdf: @products.count.to_s, orientation: 'portrait', page_size: 'A4',
               margin: { top: '2mm', bottom: '2mm', left: '0mm', right: '0mm' }, disable_smart_shrinking: true, show_as_html: params.key?('debug')
      end
    end
  end


  # POST /etichecks or /etichecks.json
  def create
    @eticheck = Eticheck.new(eticheck_params)

    respond_to do |format|
      if @eticheck.save
        format.html { redirect_to @eticheck, notice: "Eticheck was successfully created." }
        format.json { render :show, status: :created, location: @eticheck }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @eticheck.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /etichecks/1 or /etichecks/1.json
  def update
    respond_to do |format|
      if @eticheck.update(eticheck_params)
        format.html { redirect_to @eticheck, notice: "Eticheck was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @eticheck }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @eticheck.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /etichecks/1 or /etichecks/1.json
  def destroy
    @eticheck.destroy!

    respond_to do |format|
      format.html { redirect_to etichecks_path, notice: "Eticheck was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_eticheck
      @eticheck = Eticheck.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def eticheck_params
      params.require(:eticheck).permit(:itemcode, :fabricode, :varcode, :group, :description, :tg, :fabric, :qt, :materiale, :chi, :dove, :cspediti)
    end
end
