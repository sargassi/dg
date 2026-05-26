class InventoriesController < ApplicationController
  include Pagy::Backend
  before_action :set_inventory, only: %i[ show edit update destroy ]

  # GET /inventories or /inventories.json
  def index
    @inventories = Inventory.includes(:warehouse, :location, :operationtype)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @inventories = @inventories.where(
        "itemcode LIKE :q OR qtyavailable LIKE :q OR minstock LIKE :q OR maxstock LIKE :q",
        q: q
      )
    end

    @pagy, @inventories = pagy(@inventories)
  end

  # GET /inventories/1 or /inventories/1.json
  def show
  end

  def dashboard
  end

  def import
    @data = Rails.cache.read(inventories_import_cache_key)
    @warehouses = Warehouse.all
    @locations = Location.all
    @operationtypes = Operationtype.all
  end

  def import_parse
    return redirect_to inventories_import_path, alert: "Seleziona un file" unless params[:file].present?
    return redirect_to inventories_import_path, alert: "Seleziona un magazzino" unless params[:warehouse_id].present?
    return redirect_to inventories_import_path, alert: "Seleziona un tipo operazione" unless params[:operationtype_id].present?

    service = ImportInventoryService.new
    data = service.parse(params[:file],
      warehouse_id: params[:warehouse_id],
      location_id: params[:location_id],
      operationtype_id: params[:operationtype_id])
    Rails.cache.write(inventories_import_cache_key, data, expires_in: 30.minutes)
    redirect_to inventories_import_path, notice: "#{data[:rows].size} righe caricate. Verifica e modifica."
  end

  def import_update_row
    data = Rails.cache.read(inventories_import_cache_key)
    return head :not_found unless data

    row_index = params[:row_index].to_i
    field = params[:field]
    value = params[:value]

    row = data[:rows].find { |r| r[:_index] == row_index }
    return head :not_found unless row

    row[field] = value
    Rails.cache.write(inventories_import_cache_key, data, expires_in: 30.minutes)
    render json: { success: true }
  end

  def import_delete_row
    data = Rails.cache.read(inventories_import_cache_key)
    return head :not_found unless data

    row_index = params[:row_index].to_i
    data[:rows].reject! { |r| r[:_index] == row_index }

    Rails.cache.write(inventories_import_cache_key, data, expires_in: 30.minutes)
    respond_to { |format| format.turbo_stream }
  end

  def import_confirm
    data = Rails.cache.read(inventories_import_cache_key)
    return redirect_to inventories_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    stats = ImportInventoryService.new.save(data)
    Rails.cache.delete(inventories_import_cache_key)
    Rails.cache.write("import:inv:stats:#{session.id}", stats, expires_in: 5.minutes)
    redirect_to inventories_import_summary_path
  end

  def import_summary
    @stats = Rails.cache.read("import:inv:stats:#{session.id}")
    return redirect_to inventories_path unless @stats
  end

  def import_cancel
    Rails.cache.delete(inventories_import_cache_key)
    redirect_to inventories_import_path, notice: "Importazione annullata."
  end

  # GET /inventories/new
  def new
    @inventory = Inventory.new
  end

  # GET /inventories/1/edit
  def edit
  end

  # POST /inventories or /inventories.json
  def create
    @inventory = Inventory.new(inventory_params)

    respond_to do |format|
      if @inventory.save
        format.html { redirect_to inventory_url(@inventory), notice: "Inventory was successfully created." }
        format.json { render :show, status: :created, location: @inventory }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @inventory.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /inventories/1 or /inventories/1.json
  def update
    respond_to do |format|
      if @inventory.update(inventory_params)
        format.html { redirect_to inventory_url(@inventory), notice: "Inventory was successfully updated." }
        format.json { render :show, status: :ok, location: @inventory }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @inventory.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /inventories/1 or /inventories/1.json
  def destroy
    @inventory.destroy

    respond_to do |format|
      format.html { redirect_to inventories_url, notice: "Inventory was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    def inventories_import_cache_key
      "import:inv:#{session.id.to_s}"
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_inventory
      @inventory = Inventory.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def inventory_params
      params.require(:inventory).permit(:qtyavailable, :minstock, :maxstock, :warehouse_id, :location_id, :itemcode, :operationtype_id, :itemins_id, :itemouts_id, :enabled)
    end
end
