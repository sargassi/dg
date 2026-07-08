class MergeWarehousesService
  Result = Struct.new(:success, :stats, :error, keyword_init: true)

  def call(source_ids:, target_id:)
    source_ids = Array(source_ids).map(&:to_i).uniq
    target_id = target_id.to_i

    if source_ids.empty?
      return Result.new(success: false, error: "Seleziona almeno un magazzino da unire")
    end

    if source_ids.include?(target_id)
      return Result.new(success: false, error: "Il magazzino di destinazione non può essere tra quelli da unire")
    end

    sources = Warehouse.where(id: source_ids)
    target = Warehouse.find_by(id: target_id)

    unless target
      return Result.new(success: false, error: "Magazzino di destinazione non trovato")
    end

    missing = source_ids - sources.pluck(:id)
    if missing.any?
      return Result.new(success: false, error: "Magazzini non trovati: #{missing.join(', ')}")
    end

    stats = { inventories: 0, stock_levels: 0, stock_levels_merged: 0, locations: 0, itemins_details: 0, itemouts_details: 0, itemmovements_details: 0, itemmovements_src: 0, itemmovements_dst: 0, warehouses_disabled: 0 }

    ActiveRecord::Base.transaction do
      source_ids.each do |sid|
        stats[:inventories] += Inventory.where(warehouse_id: sid).update_all(warehouse_id: target_id)

        stats[:locations] += Location.where(warehouse_id: sid).update_all(warehouse_id: target_id)

        stats[:itemins_details] += IteminsDetail.where(warehouse_id: sid).update_all(warehouse_id: target_id)
        stats[:itemouts_details] += ItemoutsDetail.where(warehouse_id: sid).update_all(warehouse_id: target_id)
        stats[:itemmovements_details] += ItemmovementsDetail.where(warehouse_id: sid).update_all(warehouse_id: target_id)

        stats[:itemmovements_src] += Itemmovement.where(source_warehouse_id: sid).update_all(source_warehouse_id: target_id)
        stats[:itemmovements_dst] += Itemmovement.where(dest_warehouse_id: sid).update_all(dest_warehouse_id: target_id)

        StockLevel.where(warehouse_id: sid).find_each do |sl|
          existing = StockLevel.find_by(gencode: sl.gencode, warehouse_id: target_id, location_id: sl.location_id)
          if existing
            existing.update!(current_qty: existing.current_qty.to_i + sl.current_qty.to_i)
            sl.delete!
            stats[:stock_levels_merged] += 1
          else
            sl.update!(warehouse_id: target_id)
            stats[:stock_levels] += 1
          end
        end

        src = Warehouse.find(sid)
        src.update!(enabled: false)
        stats[:warehouses_disabled] += 1
      end
    end

    Result.new(success: true, stats: stats)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success: false, error: "Errore durante l'unione: #{e.message}")
  rescue => e
    Result.new(success: false, error: "Errore: #{e.message}")
  end
end
