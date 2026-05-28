class OperationtypesController < ApplicationController
  before_action -> { require_ability!('manage_operationtypes') }
  before_action :set_operationtype, only: %i[ show edit update destroy ]

  # GET /operationtypes or /operationtypes.json
  def index
    @operationtypes = Operationtype.all
  end

  # GET /operationtypes/1 or /operationtypes/1.json
  def show
  end

  # GET /operationtypes/new
  def new
    @operationtype = Operationtype.new
  end

  # GET /operationtypes/1/edit
  def edit
  end

  # POST /operationtypes or /operationtypes.json
  def create
    @operationtype = Operationtype.new(operationtype_params)

    respond_to do |format|
      if @operationtype.save
        format.html { redirect_to operationtype_url(@operationtype), notice: "Operationtype was successfully created." }
        format.json { render :show, status: :created, location: @operationtype }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @operationtype.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /operationtypes/1 or /operationtypes/1.json
  def update
    respond_to do |format|
      if @operationtype.update(operationtype_params)
        format.html { redirect_to operationtype_url(@operationtype), notice: "Operationtype was successfully updated." }
        format.json { render :show, status: :ok, location: @operationtype }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @operationtype.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /operationtypes/1 or /operationtypes/1.json
  def destroy
    @operationtype.destroy

    respond_to do |format|
      format.html { redirect_to operationtypes_url, notice: "Operationtype was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_operationtype
      @operationtype = Operationtype.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def operationtype_params
      params.require(:operationtype).permit(:code, :description)
    end
end
