class InventoriesController < ApplicationController
  include Pagy::Backend
  before_action :set_inventory, only: %i[ show edit update destroy ]

  # GET /inventories or /inventories.json
  def index
    @date = if params[:date].present?
      Date.parse(params[:date]) rescue Date.current
    else
      Date.current
    end

    @warehouses = Warehouse.order(:code)

    base = Inventory.where.not(gencode: nil)
      .left_joins(:itemin, :itemout)
      .where("COALESCE(itemins.indate, itemouts.indate) <= ?", @date)

    if params[:warehouse_id].present?
      base = base.where(warehouse_id: params[:warehouse_id])
    end

    @inventories = base
      .group(:gencode)
      .select(
        :gencode,
        Arel.sql("MAX(itemcode) AS itemcode"),
        Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END) - SUM(CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
      ).order(:gencode)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @inventories = @inventories.having("gencode LIKE :q", q: q)
    end

    count = base.distinct.count(:gencode)
    @pagy, @inventories = pagy(@inventories, count: count)

    gencodes = @inventories.map(&:gencode).compact
    @history_by_gencode = {}
    history_records = Inventory.where(gencode: gencodes)
      .left_joins(:itemin, :itemout)
      .where("COALESCE(itemins.indate, itemouts.indate) <= ?", @date)
      .includes(:warehouse, :location, :operationtype)
      .order(Arel.sql("COALESCE(itemins.indate, itemouts.indate) ASC"))

    if params[:warehouse_id].present?
      history_records = history_records.where(warehouse_id: params[:warehouse_id])
    end
    itemin_ids = history_records.map(&:itemins_id).compact.uniq
    itemout_ids = history_records.map(&:itemouts_id).compact.uniq
    @itemins_by_id = Itemin.includes(:operator).where(id: itemin_ids).index_by(&:id)
    @itemouts_by_id = Itemout.includes(:operator).where(id: itemout_ids).index_by(&:id)
    history_records.group_by(&:gencode).each do |gencode, records|
      @history_by_gencode[gencode] = records.group_by(&:warehouse_id)
    end

    items = Item.where(gencode: gencodes).includes(:collection).with_attached_pictures.index_by(&:gencode)
    @collection_by_gencode = items.transform_values { |item| item.collection&.description }
    @items_by_gencode = items
  end

  # GET /inventories/1 or /inventories/1.json
  def show
  end

  # GET /inventories/autocomplete
  def autocomplete
    q = "%#{params[:q]}%"
    inventories = Inventory.where(operationtype_id: 1)
      .where("gencode LIKE :q", q: q)
      .select(:gencode, :warehouse_id, :location_id)
      .distinct
      .order(:warehouse_id, :location_id, :gencode)
      .limit(20)

    wh_ids = inventories.map(&:warehouse_id).compact.uniq
    loc_ids = inventories.map(&:location_id).compact.uniq
    @warehouses = Warehouse.where(id: wh_ids).index_by(&:id)
    @locations = Location.where(id: loc_ids).index_by(&:id)
    items = Item.where(gencode: inventories.map(&:gencode).uniq).includes(:collection).index_by(&:gencode)

    net_qty_by_key = Inventory.where(gencode: inventories.map(&:gencode).uniq)
      .group(:gencode, :warehouse_id, :location_id)
      .select(
        :gencode, :warehouse_id, :location_id,
        Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END) - SUM(CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
      )
      .each_with_object({}) { |row, h| h[[row.gencode, row.warehouse_id, row.location_id]] = row.net_qty }

    result = []
    last_wh = nil
    last_loc = nil

    inventories.each do |inv|
      if inv.warehouse_id != last_wh || inv.location_id != last_loc
        wh_code = @warehouses[inv.warehouse_id]&.code
        loc_code = @locations[inv.location_id]&.code
        result << { isHeader: true, label: "#{wh_code} / #{loc_code}" }
        last_wh = inv.warehouse_id
        last_loc = inv.location_id
      end

      item = items[inv.gencode]
      next unless item

      result << {
        id: item.id,
        gencode: item.gencode,
        label: "#{item.gencode} — #{item.description}",
        collection: item.collection&.description,
        collection_id: item.collection_id,
        warehouse_id: inv.warehouse_id,
        location_id: inv.location_id,
        warehouse_code: @warehouses[inv.warehouse_id]&.code,
        location_code: @locations[inv.location_id]&.code,
        qty_remaining: net_qty_by_key[[inv.gencode, inv.warehouse_id, inv.location_id]] || 0
      }
    end

    render json: result
  end

  def dashboard
    @latest_itemins = Itemin.includes(:operator, itemins_details: [:warehouse, :location, :item]).order(indate: :desc).limit(10)
    @latest_itemouts = Itemout.includes(:operator, itemouts_details: [:warehouse, :location, :item]).order(indate: :desc).limit(10)
  end

  def movements
    @operationtypes = Operationtype.all
    @operators = User.where(user_type: "company_operator").order(:name)

    itemins = Itemin.includes(:operator, itemins_details: [:warehouse, :location, :item]).order(indate: :desc)
    itemouts = Itemout.includes(:operator, itemouts_details: [:warehouse, :location, :item]).order(indate: :desc)

    if params[:operationtype_id].present?
      if params[:operationtype_id] == "1"
        itemouts = itemouts.none
      elsif params[:operationtype_id] == "2"
        itemins = itemins.none
      end
    end

    if params[:date_from].present?
      date_from = Date.parse(params[:date_from]) rescue nil
      itemins = itemins.where("indate >= ?", date_from) if date_from
      itemouts = itemouts.where("indate >= ?", date_from) if date_from
    end

    if params[:date_to].present?
      date_to = Date.parse(params[:date_to]) rescue nil
      itemins = itemins.where("indate <= ?", date_to) if date_to
      itemouts = itemouts.where("indate <= ?", date_to) if date_to
    end

    if params[:operator_id].present?
      itemins = itemins.where(operator_id: params[:operator_id])
      itemouts = itemouts.where(operator_id: params[:operator_id])
    end

    if params[:q].present?
      q = "%#{params[:q]}%"
      itemin_ids = IteminsDetail.left_joins(:item)
        .where("items.gencode LIKE :q OR itemins_details.itemcode LIKE :q", q: q)
        .select(:itemin_id)
      itemout_ids = ItemoutsDetail.left_joins(:item)
        .where("items.gencode LIKE :q OR itemouts_details.itemcode LIKE :q", q: q)
        .select(:itemout_id)
      itemins = itemins.where(id: itemin_ids)
      itemouts = itemouts.where(id: itemout_ids)
    end

    itemins = itemins.load
    itemouts = itemouts.load

    combined = (itemins.map { |m| [m, :itemin] } + itemouts.map { |m| [m, :itemout] })
      .sort_by { |m, _| m.indate }.reverse

    @pagy = Pagy.new(count: combined.size, items: 25, page: params[:page] || 1)
    @movements = combined[@pagy.offset, @pagy.items] || []
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
      params.require(:inventory).permit(:qtyavailable, :minstock, :maxstock, :warehouse_id, :location_id, :itemcode, :gencode, :item_id, :operationtype_id, :itemins_id, :itemouts_id, :enabled)
    end
end
