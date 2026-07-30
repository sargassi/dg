class InventoryStockController < ApplicationController
  include Pagy::Backend
  include InventoriesViews
  before_action -> { require_ability!('manage_inventory') }

  def index
    @date = if params[:date].present?
      Date.parse(params[:date]) rescue Date.current
    else
      Date.current
    end

    @warehouses = Warehouse.order(:code)
    @collections = Collection.all
    show_zero = params[:show_zero] == "1"

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
      )
      unless show_zero
        @inventories = @inventories.having(Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) > 0"))
      end
      @inventories = @inventories.order(:gencode)

      count = base.distinct.count(:gencode)
      @pagy, @inventories = pagy(@inventories, count: count)
    else
      base = StockLevel.all

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

      unless show_zero
        base = base.where("COALESCE(current_qty, 0) > 0")
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

  def lookup_by_qr
    text = params[:q].to_s.strip
    result = parse_qr_code(text)
    render json: result
  end

  private

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
