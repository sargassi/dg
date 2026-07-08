class WarehousesController < ApplicationController
  before_action -> { require_ability!('manage_warehouses') }
  before_action :set_warehouse, only: %i[ show edit update destroy ]

  # GET /warehouses or /warehouses.json
  def index
    @warehouses = Warehouse.all.order(:code).includes(:locations)
    @warehouse = Warehouse.new
    @location = Location.new(enabled: true)
    @inventory_counts = Inventory.where(warehouse_id: @warehouses.pluck(:id))
                                 .group(:warehouse_id)
                                 .count
  end

  def qrcodes
    @warehouses = Warehouse.all.order(:code).includes(:locations)
    render pdf: "qrcodes_magazzini", orientation: 'portrait', page_size: 'A4',
           margin: { top: '10mm', bottom: '10mm', left: '10mm', right: '10mm' },
           disable_smart_shrinking: true, show_as_html: params.key?('debug')
  end

  def lookup_by_qr
    q = params[:q].to_s.strip
    result = { warehouse_id: nil, warehouse_code: nil, location_id: nil, location_code: nil }

    warehouse = Warehouse.find_by(gencode: q)
    if warehouse
      result[:warehouse_id] = warehouse.id
      result[:warehouse_code] = warehouse.code
    else
      location = Location.find_by(gencode: q)
      if location
        result[:location_id] = location.id
        result[:location_code] = location.code
        result[:warehouse_id] = location.warehouse_id
        result[:warehouse_code] = location.warehouse&.code
      end
    end

    render json: result
  end

  # GET /warehouses/1 or /warehouses/1.json
  def show
  end

  # GET /warehouses/new
  def new
    @warehouse = Warehouse.new
  end

  # GET /warehouses/1/edit
  def edit
  end

  # POST /warehouses or /warehouses.json
  def create
    @warehouse = Warehouse.new(warehouse_params)

    respond_to do |format|
      if @warehouse.save
        format.html { redirect_to warehouses_url, notice: "Warehouse was successfully created." }
        format.json { render :show, status: :created, location: @warehouse }
      else
        @warehouses = Warehouse.all
        @location = Location.new(enabled: true)
        format.html { render :index, status: :unprocessable_entity }
        format.json { render json: @warehouse.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /warehouses/1 or /warehouses/1.json
  def update
    respond_to do |format|
      if @warehouse.update(warehouse_params)
        format.html { redirect_to warehouses_url, notice: "Warehouse was successfully updated." }
        format.json { render :show, status: :ok, location: @warehouse }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @warehouse.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /warehouses/1 or /warehouses/1.json
  def destroy
    @warehouse.destroy

    respond_to do |format|
      format.html { redirect_to warehouses_url, notice: "Magazzino eliminato con successo." }
      format.turbo_stream { redirect_to warehouses_url, notice: "Magazzino eliminato con successo." }
      format.json { head :no_content }
    end
  end

  def merge
    @warehouses = Warehouse.order(:code)
    @stats = {}
  end

  def merge_apply
    source_ids = params[:source_ids]
    target_id = params[:target_id]

    result = MergeWarehousesService.new.call(source_ids: source_ids, target_id: target_id)

    if result.success
      redirect_to warehouses_path, notice: "Unione completata. #{result.stats[:warehouses_disabled]} magazzini uniti in #{Warehouse.find(target_id).code}. #{result.stats[:inventories]} inventari, #{result.stats[:stock_levels] + result.stats[:stock_levels_merged]} stock levels, #{result.stats[:locations]} ubicazioni aggiornati."
    else
      redirect_to merge_warehouses_path, alert: result.error
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_warehouse
      @warehouse = Warehouse.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def warehouse_params
      params.require(:warehouse).permit(:code, :address, :city, :cap, :civic, :latitude, :longitude, :enabled)
    end
end
