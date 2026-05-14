class EventypesController < ApplicationController
  before_action :set_eventype, only: %i[ show edit update destroy ]

  # GET /eventypes or /eventypes.json
  def index
    @eventypes = Eventype.all
  end

  # GET /eventypes/1 or /eventypes/1.json
  def show
  end

  # GET /eventypes/new
  def new
    @eventype = Eventype.new
  end

  # GET /eventypes/1/edit
  def edit
  end

  # POST /eventypes or /eventypes.json
  def create
    @eventype = Eventype.new(eventype_params)

    respond_to do |format|
      if @eventype.save
        format.html { redirect_to new_event_path(eventype_id: @eventype.id, start_date: params[:start_date] || Date.today), notice: "Tipo evento creato." }
        format.json { render :show, status: :created, location: @eventype }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @eventype.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /eventypes/1 or /eventypes/1.json
  def update
    respond_to do |format|
      if @eventype.update(eventype_params)
        format.html { redirect_to eventype_url(@eventype), notice: "Eventype was successfully updated." }
        format.json { render :show, status: :ok, location: @eventype }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @eventype.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /eventypes/1 or /eventypes/1.json
  def destroy
    @eventype.destroy

    respond_to do |format|
      format.html { redirect_to eventypes_url, notice: "Eventype was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_eventype
      @eventype = Eventype.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def eventype_params
      params.require(:eventype).permit(:name, :enabled, :color)
    end
end
