class MergeCollectionsService
  Result = Struct.new(:success, :stats, :error, keyword_init: true)

  def call(source_ids:, target_id:)
    source_ids = Array(source_ids).map(&:to_i).uniq
    target_id = target_id.to_i

    if source_ids.empty?
      return Result.new(success: false, error: "Seleziona almeno una collezione da unire")
    end

    if source_ids.include?(target_id)
      return Result.new(success: false, error: "La collezione di destinazione non può essere tra quelle da unire")
    end

    target = Collection.find_by(id: target_id)
    return Result.new(success: false, error: "Collezione di destinazione non trovata") unless target

    sources = Collection.where(id: source_ids)
    missing = source_ids - sources.pluck(:id)
    if missing.any?
      return Result.new(success: false, error: "Collezioni non trovate: #{missing.join(', ')}")
    end

    stats = { items_moved: 0, collections_removed: 0 }

    ActiveRecord::Base.transaction do
      source_ids.each do |sid|
        moved_ids = Item.where(collection_id: sid).pluck(:id)

        if moved_ids.any?
          Item.where(id: moved_ids).update_all(collection_id: target_id)
          stats[:items_moved] += moved_ids.size

          moved_ids.each_slice(100) do |batch|
            Item.where(id: batch).each do |item|
              new_gencode = [item.itemcode, item.fabricode, item.varcode].map(&:to_s).join + "_#{target_id}"
              item.update_columns(gencode: new_gencode)
            end
          end
        end

        Collection.find(sid).destroy!
        stats[:collections_removed] += 1
      end
    end

    Result.new(success: true, stats: stats)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success: false, error: "Errore durante l'unione: #{e.message}")
  rescue ActiveRecord::InvalidForeignKey => e
    Result.new(success: false, error: "Impossibile eliminare: #{e.message}")
  rescue => e
    Result.new(success: false, error: "Errore: #{e.message}")
  end
end
