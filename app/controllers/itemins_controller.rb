class IteminsController < ApplicationController
  before_action :set_itemin, only: %i[ show edit update destroy ]

  # GET /itemins or /itemins.json
  def index
    @itemins = Itemin.all
  end

  # GET /itemins/1 or /itemins/1.json
  def show
  end

  # GET /itemins/new
  def new
    @itemin = Itemin.new(indate: Date.current)
  end

  # GET /itemins/1/edit
  def edit
  end

  # POST /itemins or /itemins.json
  def create
    @itemin = Itemin.new(itemin_params)

    respond_to do |format|
      if @itemin.save
        format.html { redirect_to itemin_url(@itemin), notice: "Itemin was successfully created." }
        format.json { render :show, status: :created, location: @itemin }
      else
        format.html { redirect_to new_itemin_path, alert: @itemin.errors.full_messages.join(". ") }
        format.json { render json: @itemin.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /itemins/1 or /itemins/1.json
  def update
    respond_to do |format|
      if @itemin.update(itemin_params)
        format.html { redirect_to itemin_url(@itemin), notice: "Itemin was successfully updated." }
        format.json { render :show, status: :ok, location: @itemin }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @itemin.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /itemins/1 or /itemins/1.json
  def destroy
    @itemin.destroy

    respond_to do |format|
      format.html { redirect_to itemins_url, notice: "Itemin was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_itemin
      @itemin = Itemin.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def itemin_params
      params.require(:itemin).permit(:indate, :notes, :operator_id, :description,
        itemins_details_attributes: [:id, :itemcode, :qty, :item_id, :collection_id, :_destroy])
    end
end
