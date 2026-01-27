class ProformasController < ApplicationController
  before_action :set_proforma, only: %i[show edit update destroy]

  include Pagy::Backend


  # GET /proformas or /proformas.json
  def index
    @profnew = Proforma.new
    @proformas = Proforma.order('created_at desc').joins(:prows).distinct
    @pagy, @proformas = pagy(@proformas)
  end

  # GET /proformas/1 or /proformas/1.json
  def show

    if params[:done].present? && params[:done] == 'y'
      @rows = Prow.where('proforma_id = ? and done = true', @proforma.id)

    elsif params[:done].present? && params[:done] == 'n'
      @rows = Prow.where('proforma_id = ? and (done = false or done is null)', @proforma.id)
    else
      @rows = Prow.where('proforma_id = ?', @proforma.id)
    end

    respond_to do |format|
      format.html
      format.pdf do
        render :pdf => @proforma.id.to_s , orientation: "portrait",page_size: 'A4',margin:  {top:'0mm',bottom: '0m',left: '0mm',right:'0mm' }, disable_smart_shrinking: true, show_as_html: params.key?('debug')
      end
    end

  end

  # GET /proformas/new
  def new
    @proforma = Proforma.new
  end

  # GET /proformas/1/edit
  def edit; end

  # POST /proformas or /proformas.json
  def create
    file = params[:proforma][:file]
    customer = params[:proforma][:customer]
    data_in = params[:proforma][:data_in]
    @proforma = Proforma.new(proforma_params)

    respond_to do |format|
      if @proforma.save
        @proforma.data_in = data_in
        @proforma.save

        ImportProformasService.new.callnew(file, customer, @proforma.id)
        format.html { redirect_to proformas_path, notice: 'Lancio importato.' }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @proforma.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /proformas/1 or /proformas/1.json
  def update
    respond_to do |format|
      if @proforma.update(proforma_params)
        format.html { redirect_to proforma_url(@proforma), notice: 'Lancio aggiornato.' }
        format.json { render :show, status: :ok, location: @proforma }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @proforma.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /proformas/1 or /proformas/1.json
  def destroy
    chk = Prow.where('proforma_id = ?', @proforma.id)
    chk.each do |ch|
      ch.tempestas.each do |temp|
        temp.destroy
      end
      ch.destroy
    end
    @proforma.destroy

    respond_to do |format|
      format.html { redirect_to proformas_url, notice: 'Lancio eliminato.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_proforma
    @proforma = Proforma.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def proforma_params
    params.require(:proforma).permit(:customer, :data_in, :data_out, :closed, :note, :file)
  end
end
