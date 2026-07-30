class InventoryStockQuery
  attr_reader :date, :warehouse_id, :collection_id, :query, :show_zero, :include_history

  def initialize(params)
    @date = parse_date(params[:date])
    @warehouse_id = params[:warehouse_id]
    @collection_id = params[:collection_id]
    @query = params[:q]
    @show_zero = params[:show_zero] == "1"
    @include_history = false
  end

  def results
    @results ||= begin
      if historical?
        grouped_inventory_results
      else
        grouped_stock_results
      end
    end
  end

  def with_history
    @include_history = true
    self
  end

  def history_by_gencode
    return {} unless include_history

    @history_by_gencode ||= load_history
  end

  def collection_by_gencode
    @collection_by_gencode ||= items_by_gencode.transform_values { |item| item.collection&.description }
  end

  def items_by_gencode
    @items_by_gencode ||= Item.where(gencode: gencodes).includes(:collection).with_attached_pictures.index_by(&:gencode)
  end

  def gencodes
    @gencodes ||= results.map(&:gencode).compact
  end

  def inventory_scope
    @inventory_scope ||= begin
      base = Inventory.where.not(gencode: nil)
        .left_joins(:itemin, :itemout)
        .where("COALESCE(itemins.indate, itemouts.indate) <= ?", date)

      apply_stock_filters(base, inventory_join: true)
    end
  end

  def stock_scope
    @stock_scope ||= begin
      base = StockLevel.all

      if query.present?
        base = base.joins("INNER JOIN items ON items.gencode = stock_levels.gencode")
          .where("items.gencode LIKE :q OR items.itemcode LIKE :q OR items.description LIKE :q", q: "%#{query}%")
      end

      if warehouse_id.present?
        base = base.where(warehouse_id: warehouse_id)
      end

      if collection_id.present?
        base = base.joins("INNER JOIN items ON items.gencode = stock_levels.gencode")
          .where(items: { collection_id: collection_id })
      end

      unless show_zero
        base = base.where("COALESCE(current_qty, 0) > 0")
      end

      base
    end
  end

  def itemins_by_id
    @itemins_by_id ||= Itemin.includes(:operator).where(id: itemin_ids).index_by(&:id)
  end

  def itemouts_by_id
    @itemouts_by_id ||= Itemout.includes(:operator).where(id: itemout_ids).index_by(&:id)
  end

  def itemmovements_by_id
    @itemmovements_by_id ||= Itemmovement.includes(:operator, :source_warehouse, :dest_warehouse, :source_location, :dest_location).where(id: itemmovement_ids).index_by(&:id)
  end

  def itemin_ids
    @itemin_ids ||= history_records.map(&:itemins_id).compact.uniq
  end

  def itemout_ids
    @itemout_ids ||= history_records.map(&:itemouts_id).compact.uniq
  end

  def itemmovement_ids
    @itemmovement_ids ||= history_records.map(&:itemmovement_id).compact.uniq
  end

  private

  def historical?
    date && date.to_date != Date.current
  end

  def parse_date(raw)
    if raw.present?
      Date.parse(raw) rescue Date.current
    else
      Date.current
    end
  end

  def apply_stock_filters(base, inventory_join: false)
    if warehouse_id.present?
      base = base.where(warehouse_id: warehouse_id)
    end

    if collection_id.present? || query.present?
      base = base.joins("INNER JOIN items ON items.gencode = #{inventory_join ? 'inventories.gencode' : 'stock_levels.gencode'}")

      if collection_id.present?
        base = base.where(items: { collection_id: collection_id })
      end

      if query.present?
        q = "%#{query}%"
        base = base.where("items.gencode LIKE :q OR items.itemcode LIKE :q OR items.description LIKE :q", q: q)
      end
    end

    base
  end

  def grouped_inventory_results
    base = inventory_scope

    result = base.group(:gencode).select(
      :gencode,
      Arel.sql("MAX(inventories.itemcode) AS itemcode"),
      Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) AS net_qty")
    )

    unless show_zero
      result = result.having(Arel.sql("SUM(CASE WHEN operationtype_id = 1 THEN COALESCE(qtyavailable, 0) ELSE 0 END - CASE WHEN operationtype_id = 2 THEN COALESCE(qtyavailable, 0) ELSE 0 END) > 0"))
    end

    result.order(:gencode)
  end

  def grouped_stock_results
    stock_scope.group(:gencode)
      .select(:gencode, Arel.sql("SUM(current_qty) AS current_qty"))
      .order(:gencode)
  end

  def load_history
    records = Inventory.where(gencode: gencodes)
      .left_joins(:itemin, :itemout, :itemmovement)
      .where("COALESCE(itemins.indate, itemouts.indate, itemmovements.indate) <= ?", date)
      .includes(:warehouse, :location, :operationtype)
      .order(Arel.sql("COALESCE(itemins.indate, itemouts.indate, itemmovements.indate) ASC, inventories.created_at ASC"))

    if warehouse_id.present?
      records = records.where(warehouse_id: warehouse_id)
    end

    records.group_by(&:gencode).transform_values do |gencode_records|
      gencode_records.group_by(&:warehouse_id).transform_values do |wh_records|
        wh_records.group_by { |r| r.location_id || 0 }.transform_values do |loc_records|
          loc_records.partition { |r| !r.itemmovement_id }.flatten
        end
      end
    end
  end

  def history_records
    @history_records ||= begin
      records = Inventory.where(gencode: gencodes)
        .left_joins(:itemin, :itemout, :itemmovement)
        .where("COALESCE(itemins.indate, itemouts.indate, itemmovements.indate) <= ?", date)
        .includes(:warehouse, :location, :operationtype)
        .order(Arel.sql("COALESCE(itemins.indate, itemouts.indate, itemmovements.indate) ASC, inventories.created_at ASC"))

      if warehouse_id.present?
        records = records.where(warehouse_id: warehouse_id)
      end
      records
    end
  end
end
