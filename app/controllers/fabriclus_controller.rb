class FabriclusController < ApplicationController
  before_action :set_fabriclu, only: %i[ show edit update destroy ]

  include Pagy::Backend


  # GET /fabriclus or /fabriclus.json
  def index
    @fabriclus = Fabriclu.all
    @pagy, @fabriclus = pagy(@fabriclus)
  end

  # GET /fabriclus/1 or /fabriclus/1.json
  def show
  end

  # GET /fabriclus/new
  def new
    @fabriclu = Fabriclu.new
  end

  # GET /fabriclus/1/edit
  def edit
  end

  # POST /fabriclus or /fabriclus.json
  def create
    @fabriclu = Fabriclu.new(fabriclu_params)

    respond_to do |format|
      if @fabriclu.save
        format.html { redirect_to fabriclu_url(@fabriclu), notice: "Fabriclu was successfully created." }
        format.json { render :show, status: :created, location: @fabriclu }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @fabriclu.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /fabriclus/1 or /fabriclus/1.json
  def update
    respond_to do |format|
      if @fabriclu.update(fabriclu_params)
        format.html { redirect_to fabriclu_url(@fabriclu), notice: "Fabriclu was successfully updated." }
        format.json { render :show, status: :ok, location: @fabriclu }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @fabriclu.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /fabriclus/1 or /fabriclus/1.json
  def destroy
    @fabriclu.destroy

    respond_to do |format|
      format.html { redirect_to fabriclus_url, notice: "Fabriclu was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def import
    file = params[:file]
    cid = params[:company_id]
    return redirect_to fabriclus_path, notice: 'Solo CSV, please' unless file.content_type == 'text/csv'
      ImportHistoryTextService.new.call(file)
      return redirect_to fabriclus_path, notice: 'Tabella importata'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_fabriclu
      @fabriclu = Fabriclu.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def fabriclu_params
      params.require(:fabriclu).permit(:fab, :var, :year, :description, :note, :tg, :color, :qty, :materiale, :customer, :supplier, :mtkg, :mtkg20, :mtkgprezzi, :mtkg20prezzi, :perche)
    end
end
