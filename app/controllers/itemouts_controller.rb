class ItemoutsController < ApplicationController
  before_action :set_itemout, only: %i[ show edit update destroy ]

  # GET /itemouts or /itemouts.json
  def index
    @itemouts = Itemout.all
  end

  # GET /itemouts/1 or /itemouts/1.json
  def show
  end

  # GET /itemouts/new
  def new
    @itemout = Itemout.new
  end

  # GET /itemouts/1/edit
  def edit
  end

  # POST /itemouts or /itemouts.json
  def create
    @itemout = Itemout.new(itemout_params)

    respond_to do |format|
      if @itemout.save
        format.html { redirect_to itemout_url(@itemout), notice: "Itemout was successfully created." }
        format.json { render :show, status: :created, location: @itemout }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @itemout.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /itemouts/1 or /itemouts/1.json
  def update
    respond_to do |format|
      if @itemout.update(itemout_params)
        format.html { redirect_to itemout_url(@itemout), notice: "Itemout was successfully updated." }
        format.json { render :show, status: :ok, location: @itemout }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @itemout.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /itemouts/1 or /itemouts/1.json
  def destroy
    @itemout.destroy

    respond_to do |format|
      format.html { redirect_to itemouts_url, notice: "Itemout was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_itemout
      @itemout = Itemout.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def itemout_params
      params.require(:itemout).permit(:indate)
    end
end
