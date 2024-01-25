class RassegnasController < ApplicationController
  before_action :set_rassegna, only: %i[ show edit update destroy ]
  before_action :authenticate_user!, only: [:new, :create, :destroy]

  # GET /rassegnas or /rassegnas.json
  def index
    #@rassegnas = Rassegna.all.with_rich_text_description
    @q = Rassegna.ransack(params[:q])
    @rassegnas = @q.result(distinct: true)
  end

  # GET /rassegnas/1 or /rassegnas/1.json
  def show
    
  end

  def salvati
    @rassegnas = Rassegna.all
  end

  # GET /rassegnas/new
  def new
    @rassegna = Rassegna.new
  end

  # GET /rassegnas/1/edit
  def edit
  end

  # POST /rassegnas or /rassegnas.json
  def create
    @rassegna = Rassegna.new(rassegna_params)
    #@rassegna.user_id = current_user.id

    respond_to do |format|
      if @rassegna.save
        format.html { redirect_to rassegna_url(@rassegna), notice: "Rassegna was successfully created." }
        format.json { render :show, status: :created, location: @rassegna }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @rassegna.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /rassegnas/1 or /rassegnas/1.json
  def update
    respond_to do |format|
      if @rassegna.update(rassegna_params)
        format.html { redirect_to rassegna_url(@rassegna), notice: "Rassegna was successfully updated." }
        format.json { render :show, status: :ok, location: @rassegna }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @rassegna.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /rassegnas/1 or /rassegnas/1.json
  def destroy
    @rassegna.destroy
    respond_to do |format|
      format.html { redirect_to rassegnas_url, notice: "Rassegna was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_rassegna
      @rassegna = Rassegna.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def rassegna_params
      params.require(:rassegna).permit(:titolo, :tipologia, :anno, :paese, :testata, :giornalista, :medium, :pagine, :descrizione,  :photo, :photo_cache, :salva, :data, :paginea, :fotografo)
    end
end

