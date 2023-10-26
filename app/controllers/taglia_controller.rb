class TagliaController < ApplicationController
  before_action :set_taglium, only: %i[ show edit update destroy ]

  # GET /taglia or /taglia.json
  def index
    @taglia = Taglium.all
  end

  # GET /taglia/1 or /taglia/1.json
  def show
  end

  # GET /taglia/new
  def new
    @taglium = Taglium.new
  end

  # GET /taglia/1/edit
  def edit
  end

  # POST /taglia or /taglia.json
  def create
    @taglium = Taglium.new(taglium_params)

    respond_to do |format|
      if @taglium.save
        format.html { redirect_to taglium_url(@taglium), notice: "Taglium was successfully created." }
        format.json { render :show, status: :created, location: @taglium }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @taglium.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /taglia/1 or /taglia/1.json
  def update
    respond_to do |format|
      if @taglium.update(taglium_params)
        format.html { redirect_to taglium_url(@taglium), notice: "Taglium was successfully updated." }
        format.json { render :show, status: :ok, location: @taglium }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @taglium.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /taglia/1 or /taglia/1.json
  def destroy
    @taglium.destroy

    respond_to do |format|
      format.html { redirect_to taglia_url, notice: "Taglium was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_taglium
      @taglium = Taglium.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def taglium_params
      params.require(:taglium).permit(:description)
    end
end
