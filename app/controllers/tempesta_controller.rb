class TempestaController < ApplicationController
  before_action :set_tempestum, only: %i[ show edit update destroy ]

  # GET /tempesta or /tempesta.json
  def index
    @tempesta = Tempestum.all
  end

  # GET /tempesta/1 or /tempesta/1.json
  def show
  end

  # GET /tempesta/new
  def new
    @tempestum = Tempestum.new
  end

  # GET /tempesta/1/edit
  def edit
  end

  # POST /tempesta or /tempesta.json
  def create
    @tempestum = Tempestum.new(tempestum_params)

    respond_to do |format|
      if @tempestum.save
        format.html { redirect_to tempestum_url(@tempestum), notice: "Tempestum was successfully created." }
        format.json { render :show, status: :created, location: @tempestum }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @tempestum.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /tempesta/1 or /tempesta/1.json
  def update
    respond_to do |format|
      if @tempestum.update(tempestum_params)
        format.html { redirect_to tempestum_url(@tempestum), notice: "Tempestum was successfully updated." }
        format.json { render :show, status: :ok, location: @tempestum }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @tempestum.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tempesta/1 or /tempesta/1.json
  def destroy
    @tempestum.destroy

    respond_to do |format|
      format.html { redirect_to tempesta_url, notice: "Tempestum was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tempestum
      @tempestum = Tempestum.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def tempestum_params
      params.require(:tempestum).permit(:prow_id, :f0, :f1, :f2, :f3, :f4, :f5, :f1date, :f2date, :f3date, :f4date, :f5date)
    end
end
