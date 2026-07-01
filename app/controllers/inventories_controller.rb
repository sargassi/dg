class InventoriesController < ApplicationController
  include Pagy::Backend
  before_action -> { require_ability!('manage_inventory') }
  before_action :set_inventory, only: %i[ show edit update destroy ]

  # GET /inventories or /inventories.json
  def index
    @date = if params[:date].present?
      Date.parse(params[:date]) rescue Date.current
    else
      Date.current
    end

    @warehouses = Warehouse.order(:code)
    @collections = Collection.all

    if params[:date].present? && params[:date].to_date != Date.current
      # Historical date — use event log (slower but accurate)
      base = Inventory.where.not(gencode: nil)
        .left_joins(:itemin, :itemout)
        .where("COALESCE(itemins.indate, itemouts.indate) <= ?", @date)

      if params[:warehouse_id].present?
        base = base.where(warehouse_id: params[:warehouse_id])
      end
      if params[:collection_id].present? || params[:q].present?
        base = base.joins("INNER JOIN items ON items.gencode = inventories.gencode")
        if params[:collection_id].present?
          base = base.where(items: { collection_id: params[:collection_id] })
        end
        if params[:q].present?
          q = "%#{params[:q]}%"
          base = base.where("items.gencode LIKE :q OR items.itemcode LIKE :q OR items.description LIKE :q", q: q)
        end
      end

      @inventories = base.group(:gencode).select(
        :gencode,
        Arel.sql("MAX(inventories.itemcode) AS itemcode"),
        Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
      ).order(:gencode)

      count = base.distinct.count(:gencode)
      @pagy, @inventories = pagy(@inventories, count: count)
    else
      # Current stock — use StockLevel (fast)
      base = StockLevel.positive

      if params[:q].present?
        q = "%#{params[:q]}%"
        base = base.joins("INNER JOIN items ON items.gencode = stock_levels.gencode")
          .where("items.gencode LIKE :q OR items.itemcode LIKE :q OR items.description LIKE :q", q: q)
      end

      if params[:warehouse_id].present?
        base = base.where(warehouse_id: params[:warehouse_id])
      end

      if params[:collection_id].present?
        base = base.joins("INNER JOIN items ON items.gencode = stock_levels.gencode")
          .where(items: { collection_id: params[:collection_id] })
      end

      count = base.distinct.count(:gencode)
      @inventories = base.group(:gencode)
        .select(:gencode, Arel.sql("SUM(current_qty) AS current_qty"))
        .order(:gencode)
      @pagy, @inventories = pagy(@inventories, count: count)
    end

    gencodes = @inventories.map(&:gencode).compact
    @history_by_gencode = {}
    history_records = Inventory.where(gencode: gencodes)
      .left_joins(:itemin, :itemout, :itemmovement)
      .where("COALESCE(itemins.indate, itemouts.indate, itemmovements.indate) <= ?", @date)
      .includes(:warehouse, :location, :operationtype)
      .order(Arel.sql("COALESCE(itemins.indate, itemouts.indate, itemmovements.indate) ASC, inventories.created_at ASC"))

    if params[:warehouse_id].present?
      history_records = history_records.where(warehouse_id: params[:warehouse_id])
    end
    itemin_ids = history_records.map(&:itemins_id).compact.uniq
    itemout_ids = history_records.map(&:itemouts_id).compact.uniq
    itemmovement_ids = history_records.map(&:itemmovement_id).compact.uniq
    @itemins_by_id = Itemin.includes(:operator).where(id: itemin_ids).index_by(&:id)
    @itemouts_by_id = Itemout.includes(:operator).where(id: itemout_ids).index_by(&:id)
    @itemmovements_by_id = Itemmovement.includes(:operator, :source_warehouse, :dest_warehouse, :source_location, :dest_location).where(id: itemmovement_ids).index_by(&:id)

    history_records.group_by(&:gencode).each do |gencode, records|
      @history_by_gencode[gencode] = records.group_by(&:warehouse_id).transform_values do |wh_records|
        wh_records.group_by { |r| r.location_id || 0 }.transform_values do |loc_records|
          loc_records.partition { |r| !r.itemmovement_id }.flatten
        end
      end
    end

    items = Item.where(gencode: gencodes).includes(:collection).with_attached_pictures.index_by(&:gencode)
    @collection_by_gencode = items.transform_values { |item| item.collection&.description }
    @items_by_gencode = items
  end

  # GET /inventories/export_xlsx
  def export_xlsx
    @date = if params[:date].present?
      Date.parse(params[:date]) rescue Date.current
    else
      Date.current
    end

    if params[:date].present? && params[:date].to_date != Date.current
      base = Inventory.where.not(gencode: nil)
        .left_joins(:itemin, :itemout)
        .where("COALESCE(itemins.indate, itemouts.indate) <= ?", @date)

      if params[:warehouse_id].present?
        base = base.where(warehouse_id: params[:warehouse_id])
      end
      if params[:collection_id].present? || params[:q].present?
        base = base.joins("INNER JOIN items ON items.gencode = inventories.gencode")
        if params[:collection_id].present?
          base = base.where(items: { collection_id: params[:collection_id] })
        end
        if params[:q].present?
          q = "%#{params[:q]}%"
          base = base.where("items.gencode LIKE :q OR items.itemcode LIKE :q OR items.description LIKE :q", q: q)
        end
      end

      @inventories = base.group(:gencode).select(
        :gencode,
        Arel.sql("MAX(inventories.itemcode) AS itemcode"),
        Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
      ).order(:gencode)
    else
      base = StockLevel.positive

      if params[:q].present?
        q = "%#{params[:q]}%"
        base = base.joins("INNER JOIN items ON items.gencode = stock_levels.gencode")
          .where("items.gencode LIKE :q OR items.itemcode LIKE :q OR items.description LIKE :q", q: q)
      end

      if params[:warehouse_id].present?
        base = base.where(warehouse_id: params[:warehouse_id])
      end

      if params[:collection_id].present?
        base = base.joins("INNER JOIN items ON items.gencode = stock_levels.gencode")
          .where(items: { collection_id: params[:collection_id] })
      end

      @inventories = base.group(:gencode)
        .select(:gencode, Arel.sql("SUM(current_qty) AS current_qty"))
        .order(:gencode)
    end

    gencodes = @inventories.map(&:gencode).compact
    items = Item.where(gencode: gencodes).includes(:collection).index_by(&:gencode)
    @collection_by_gencode = items.transform_values { |item| item.collection&.description }
    @items_by_gencode = items

    warehouse_label = params[:warehouse_id].present? ? Warehouse.find_by(id: params[:warehouse_id])&.code || params[:warehouse_id] : "Tutti"
    collection_label = params[:collection_id].present? ? Collection.find_by(id: params[:collection_id])&.description || params[:collection_id] : "Tutte"

    package = Axlsx::Package.new
    wb = package.workbook
    wb.add_worksheet(name: "Inventario") do |sheet|
      sheet.add_row ["Data", @date.strftime("%d-%m-%Y"), "Magazzino", warehouse_label, "Collezione", collection_label]
      sheet.add_row
      sheet.add_row ["Codice", "Collezione", "Descrizione", "Quantità"]
      @inventories.each do |inv|
        item = @items_by_gencode[inv.gencode]
        next unless item
        qty = inv.respond_to?(:current_qty) ? inv.current_qty : inv.net_qty.to_i
        sheet.add_row [
          "#{item.itemcode}#{item.fabricode}#{item.varcode}",
          @collection_by_gencode[inv.gencode],
          item.description,
          qty
        ]
      end
    end

    send_data package.to_stream.read,
      filename: "inventario_#{@date.strftime("%Y-%m-%d")}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end

  # GET /inventories/1 or /inventories/1.json
  def show
  end

  # GET /inventories/autocomplete
  def autocomplete
    q = "%#{params[:q]}%"
    inventories = Inventory.where(operationtype_id: 1)
      .where("gencode LIKE :q OR itemcode LIKE :q", q: q)
    if params[:warehouse_id].present?
      inventories = inventories.where(warehouse_id: params[:warehouse_id])
    end
    if params[:location_id].present?
      inventories = inventories.where(location_id: params[:location_id])
    end
    inventories = inventories
      .select(:gencode, :warehouse_id, :location_id)
      .distinct
      .order(:warehouse_id, :location_id, :gencode)
      .limit(20)

    wh_ids = inventories.map(&:warehouse_id).compact.uniq
    loc_ids = inventories.map(&:location_id).compact.uniq
    @warehouses = Warehouse.where(id: wh_ids).index_by(&:id)
    @locations = Location.where(id: loc_ids).index_by(&:id)
    items = Item.where(gencode: inventories.map(&:gencode).uniq).includes(:collection).index_by(&:gencode)

    stock_levels = StockLevel.where(gencode: inventories.map(&:gencode).uniq)
    net_qty_by_key = stock_levels.each_with_object({}) { |sl, h|
      h[[sl.gencode, sl.warehouse_id, sl.location_id]] = sl.current_qty
    }

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

      qty_remaining = net_qty_by_key[[inv.gencode, inv.warehouse_id, inv.location_id]] || 0
      next if qty_remaining <= 0

      result << {
        id: item.id,
        gencode: item.gencode,
        itemcode: item.itemcode,
        fabricode: item.fabricode,
        varcode: item.varcode,
        label: "#{item.itemcode}#{item.fabricode}#{item.varcode}",
        collection: item.collection&.description,
        collection_id: item.collection_id,
        warehouse_id: inv.warehouse_id,
        location_id: inv.location_id,
        warehouse_code: @warehouses[inv.warehouse_id]&.code,
        location_code: @locations[inv.location_id]&.code,
        qty_remaining: qty_remaining
      }
    end

    render json: result
  end

  def dashboard
    @latest_itemins = Itemin.includes(:operator, itemins_details: [:warehouse, :location, :item]).order(indate: :desc).limit(10)
    @latest_itemouts = Itemout.includes(:operator, itemouts_details: [:warehouse, :location, :item]).order(indate: :desc).limit(10)
    @latest_itemmovements = Itemmovement.includes(:operator, :source_warehouse, :dest_warehouse, :source_location, :dest_location, itemmovements_details: :item).order(indate: :desc).limit(10)
  end

  def seleziona
    @collections = Collection.joins(:items).distinct.order(row_order: :desc)
    @itemz = Item.includes(:collection).with_attached_pictures

    if params[:collection_id].present?
      @itemz = @itemz.where(collection_id: params[:collection_id])
    end

    if params[:q].present?
      q = "%#{params[:q]}%"
      @itemz = @itemz.where(
        "gencode LIKE :q OR itemcode LIKE :q OR fabricode LIKE :q OR varcode LIKE :q OR description LIKE :q OR fabric LIKE :q OR colour LIKE :q",
        q: q
      )
    end

    @pagy, @itemz = pagy(@itemz)
  end

  def prepare_carico
    selected = params[:selected] || []
    session[:carico_prefill] = selected.map { |s| s.permit(:item_id, :gencode, :collection_id, :qty).to_h }
    redirect_to app_in_warehouse_path, notice: "#{selected.size} articoli pronti per il carico."
  end

  def movements
    @operationtypes = Operationtype.all
    @operators = User.where(user_type: "company_operator").order(:name)

    itemins = Itemin.includes(:operator, itemins_details: [:warehouse, :location, :item]).order(indate: :desc)
    itemouts = Itemout.includes(:operator, itemouts_details: [:warehouse, :location, :item]).order(indate: :desc)
    itemmovements = Itemmovement.includes(:operator, :source_warehouse, :dest_warehouse, :source_location, :dest_location, itemmovements_details: :item).order(indate: :desc)

    if params[:operationtype_id].present?
      case params[:operationtype_id]
      when "1" then itemouts = itemouts.none; itemmovements = itemmovements.none
      when "2" then itemins = itemins.none; itemmovements = itemmovements.none
      when "3" then itemins = itemins.none; itemouts = itemouts.none
      end
    end

    if params[:date_from].present?
      date_from = Date.parse(params[:date_from]) rescue nil
      itemins = itemins.where("indate >= ?", date_from) if date_from
      itemouts = itemouts.where("indate >= ?", date_from) if date_from
      itemmovements = itemmovements.where("indate >= ?", date_from) if date_from
    end

    date_to = params[:date_to].present? ? (Date.parse(params[:date_to]) rescue nil) : Date.current
    if date_to
      itemins = itemins.where("indate <= ?", date_to)
      itemouts = itemouts.where("indate <= ?", date_to)
      itemmovements = itemmovements.where("indate <= ?", date_to)
    end

    if params[:operator_id].present?
      itemins = itemins.where(operator_id: params[:operator_id])
      itemouts = itemouts.where(operator_id: params[:operator_id])
      itemmovements = itemmovements.where(operator_id: params[:operator_id])
    end

    if params[:q].present?
      q = "%#{params[:q]}%"
      itemin_ids = IteminsDetail.left_joins(:item)
        .where("items.gencode LIKE :q OR itemins_details.itemcode LIKE :q", q: q).select(:itemin_id)
      itemout_ids = ItemoutsDetail.left_joins(:item)
        .where("items.gencode LIKE :q OR itemouts_details.itemcode LIKE :q", q: q).select(:itemout_id)
      itemmovement_ids = ItemmovementsDetail.left_joins(:item)
        .where("items.gencode LIKE :q OR itemmovements_details.itemcode LIKE :q", q: q).select(:itemmovement_id)
      itemins = itemins.where(id: itemin_ids)
      itemouts = itemouts.where(id: itemout_ids)
      itemmovements = itemmovements.where(id: itemmovement_ids)
    end

    itemins = itemins.load
    itemouts = itemouts.load
    itemmovements = itemmovements.load

    combined = (itemins.map { |m| [m, :itemin] } + itemouts.map { |m| [m, :itemout] } + itemmovements.map { |m| [m, :itemmovement] })
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
    Rails.cache.delete("import:inv:stats:#{session.id}")
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
    @data = Rails.cache.read(inventories_import_cache_key)
    return head :not_found unless @data

    row_index = params[:row_index].to_i
    @data[:rows].reject! { |r| r[:_index] == row_index }

    Rails.cache.write(inventories_import_cache_key, @data, expires_in: 30.minutes)
    respond_to { |format| format.turbo_stream }
  end

  def import_confirm
    data = Rails.cache.read(inventories_import_cache_key)
    return redirect_to inventories_import_path, alert: "Nessun dato da importare" unless data&.dig(:rows)&.any?

    stats = ImportInventoryService.new.save(data, current_user)
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

  def movement_label
    @movement_type = params[:type]
    @items = case @movement_type
    when "itemin"
      Itemin.includes(itemins_details: :item).find(params[:id]).itemins_details
    when "itemout"
      Itemout.includes(itemouts_details: :item).find(params[:id]).itemouts_details
    when "itemmovement"
      Itemmovement.includes(itemmovements_details: :item).find(params[:id]).itemmovements_details
    else
      return redirect_to inventories_movements_path, alert: "Tipo movimento non valido"
    end

    render pdf: "etichette_#{params[:type]}_#{params[:id]}",
           orientation: "portrait",
           page_size: "A4",
           margin: { top: "0mm", bottom: "0mm", left: "0mm", right: "0mm" },
           disable_smart_shrinking: true,
           show_as_html: params.key?("debug")
  end

  def movement_modal
    @record = case params[:type]
    when "itemin"
      Itemin.includes(itemins_details: [:warehouse, :location, :operationtype, :item]).find(params[:id])
    when "itemout"
      Itemout.includes(itemouts_details: [:warehouse, :location, :operationtype, :item]).find(params[:id])
    when "itemmovement"
      Itemmovement.includes(itemmovements_details: [:item]).find(params[:id])
    end
    @type = params[:type].to_sym
    render layout: false
  end

  # GET /inventories/lookup_by_qr
  def lookup_by_qr
    text = params[:q].to_s.strip
    result = parse_qr_code(text)
    render json: result
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

    def parse_qr_code(scanned_text)
      parsed = QrParser.parse(scanned_text)

      item = Item.find_by(gencode: parsed[:gencode])
      return { error: "Item not found" } unless item

      if parsed[:detail_id]
        detail = IteminsDetail.find_by(id: parsed[:detail_id])
        if detail
          last_inventory = find_last_ingress(item, detail.created_at)
          return {
            format: "itemins",
            item: item_summary(item),
            collection_id: parsed[:collection_id] || detail.collection_id,
            inbound: {
              warehouse_id: detail.warehouse_id,
              location_id: detail.location_id,
              warehouse: detail.warehouse&.code,
              location: detail.location&.code
            },
            last_position: last_inventory ? {
              warehouse_id: last_inventory.warehouse_id,
              location_id: last_inventory.location_id,
              warehouse: last_inventory.warehouse&.code,
              location: last_inventory.location&.code,
              since: last_inventory.created_at
            } : nil
          }
        end
      end

      legacy_qr_result(item)
    end

    def legacy_qr_result(item)
      positions = StockLevel.where(gencode: item.gencode).positive.includes(:warehouse, :location)

      {
        format: "legacy",
        item: item_summary(item),
        collection_id: item.collection_id,
        positions: positions.map { |sl|
          {
            warehouse_id: sl.warehouse_id,
            location_id: sl.location_id,
            warehouse: sl.warehouse&.code,
            location: sl.location&.code,
            net_qty: sl.current_qty
          }
        }
      }
    end

    def item_summary(item)
      {
        id: item.id,
        gencode: item.gencode,
        itemcode: item.itemcode,
        fabricode: item.fabricode,
        varcode: item.varcode,
        description: item.description,
        collection: item.collection&.description
      }
    end

    def find_last_ingress(item, after_date)
      Inventory.where(item_id: item.id, operationtype_id: 1)
        .where("created_at > ?", after_date)
        .order(created_at: :desc)
        .first
    end
end
