class ReassignStockService
  Result = Struct.new(:success, :stats, :error, keyword_init: true)

  def self.call(**kwargs)
    new.call(**kwargs)
  end

  def call(gencodes:, src_warehouse_id:, src_location_id: nil, dst_warehouse_id:, dst_location_id: nil)
    gencodes = Array(gencodes).map(&:to_s).compact.uniq
    src_wh = src_warehouse_id.to_i
    dst_wh = dst_warehouse_id.to_i
    src_loc = src_location_id.to_i
    dst_loc = dst_location_id.to_i

    if gencodes.empty?
      return Result.new(success: false, error: "Seleziona almeno un articolo")
    end

    if src_wh.zero?
      return Result.new(success: false, error: "Seleziona un magazzino di origine")
    end

    if dst_wh.zero?
      return Result.new(success: false, error: "Seleziona un magazzino di destinazione")
    end

    if src_wh == dst_wh && src_loc == dst_loc
      return Result.new(success: false, error: "Origine e destinazione coincidono")
    end

    unless Warehouse.exists?(id: src_wh)
      return Result.new(success: false, error: "Magazzino di origine non trovato")
    end

    unless Warehouse.exists?(id: dst_wh)
      return Result.new(success: false, error: "Magazzino di destinazione non trovato")
    end

    stats = { moved: 0, inventories: 0, no_stock: [], moved_place: {} }

    ActiveRecord::Base.transaction do
      gencodes.each do |gencode|
        moved = move_gencode(gencode, src_wh, src_loc, dst_wh, dst_loc)
        if moved[:stock] > 0
          stats[:moved] += moved[:stock]
          stats[:inventories] += moved[:inventories]
          stats[:moved_place][gencode] = moved
        else
          stats[:no_stock] << gencode
        end
      end
    end

    if stats[:moved].zero?
      return Result.new(success: false, error: "Nessuna giacenza trovata per gli articoli selezionati in origine")
    end

    Result.new(success: true, stats: stats)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success: false, error: "Errore durante la riallocazione: #{e.message}")
  rescue => e
    Result.new(success: false, error: "Errore: #{e.message}")
  end

  private

  def move_gencode(gencode, src_wh, src_loc, dst_wh, dst_loc)
    rows = source_rows(gencode, src_wh, src_loc)
    result = { stock: 0, inventories: 0 }

    rows.each do |sl|
      qty = sl.current_qty.to_i
      next unless qty.positive?

      if sl.warehouse_id == dst_wh && sl.location_id == dst_loc
        next
      end

      StockLevel.adjust_qty!(gencode, dst_wh, dst_loc, qty)
      StockLevel.adjust_qty!(gencode, sl.warehouse_id, sl.location_id, -qty)

      src_row = StockLevel.find_by(gencode: gencode, warehouse_id: sl.warehouse_id, location_id: sl.location_id)
      src_row.destroy! if src_row && src_row.current_qty.to_i <= 0

      updated = update_inventory(gencode, sl.warehouse_id, sl.location_id, dst_wh, dst_loc)
      result[:inventories] += updated
      result[:stock] += qty
    end

    result
  end

  def source_rows(gencode, src_wh, src_loc)
    scope = StockLevel.where(gencode: gencode, warehouse_id: src_wh).positive
    scope = scope.where(location_id: src_loc) if src_loc.positive?
    scope
  end

  def update_inventory(gencode, src_wh, src_loc, dst_wh, dst_loc)
    scope = Inventory.where(gencode: gencode, warehouse_id: src_wh)
    scope = scope.where(location_id: src_loc) if src_loc.positive?
    new_loc = dst_loc.positive? ? dst_loc : nil
    scope.update_all(warehouse_id: dst_wh, location_id: new_loc)
  end
end
