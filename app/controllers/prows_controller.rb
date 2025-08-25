class ProwsController < ApplicationController
  before_action :set_prow, only: %i[ show edit update destroy ]

  # GET /prows or /prows.json
  def index
    @prows = Prow.all
  end

  # GET /prows/1 or /prows/1.json
  def show
  end

  # GET /prows/new
  def new
    @prow = Prow.new
  end

  # GET /prows/1/edit
  def edit
  end

  # POST /prows or /prows.json
  def create
    @prow = Prow.new(prow_params)

    respond_to do |format|
      if @prow.save
        format.html { redirect_to prow_url(@prow), notice: "Prow was successfully created." }
        format.json { render :show, status: :created, location: @prow }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @prow.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /prows/1 or /prows/1.json
  def update
    respond_to do |format|
      if @prow.update(prow_params)
        format.html { redirect_to prow_url(@prow), notice: "Prow was successfully updated." }
        format.json { render :show, status: :ok, location: @prow }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @prow.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /prows/1 or /prows/1.json
  def destroy
    @prow.destroy

    respond_to do |format|
      format.html { redirect_to prows_url, notice: "Prow was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_prow
      @prow = Prow.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def prow_params
      params.require(:prow).permit(:code, :proforma_id, :description, :note, :qty, :qr, :itemcode, :fabricode, :varcode, :tg, :color, :materiale, :origine, :doe)
    end
end
