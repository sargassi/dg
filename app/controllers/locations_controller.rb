class LocationsController < ApplicationController
  before_action -> { require_ability!('manage_locations') }
  before_action :set_location, only: %i[ show edit update destroy ]

  # GET /locations or /locations.json
  def index
    @locations = Location.all.order(:code).includes(:warehouse)
  end

  # GET /locations/1 or /locations/1.json
  def show
  end

  # GET /locations/new
  def new
    @location = Location.new
  end

  # GET /locations/1/edit
  def edit
  end

  # POST /locations or /locations.json
  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        format.html { redirect_to warehouses_url, notice: "Ubica creata con successo." }
        format.turbo_stream { redirect_to warehouses_url, notice: "Ubica creata con successo." }
        format.json { render :show, status: :created, location: @location }
      else
        format.html { redirect_to warehouses_url, alert: @location.errors.full_messages.to_sentence }
        format.turbo_stream { redirect_to warehouses_url, alert: @location.errors.full_messages.to_sentence }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to warehouses_url, notice: "Ubica aggiornata con successo." }
        format.turbo_stream { redirect_to warehouses_url, notice: "Ubica aggiornata con successo." }
        format.json { render :show, status: :ok, location: @location }
      else
        format.html { redirect_to warehouses_url, alert: @location.errors.full_messages.to_sentence }
        format.turbo_stream { redirect_to warehouses_url, alert: @location.errors.full_messages.to_sentence }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @location.destroy

    respond_to do |format|
      format.html { redirect_to warehouses_url, notice: "Ubica eliminata con successo." }
      format.turbo_stream { redirect_to warehouses_url, notice: "Ubica eliminata con successo." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_location
      @location = Location.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def location_params
      params.require(:location).permit(:code, :warehouse_id, :enabled)
    end
end
