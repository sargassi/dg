class ImportValidator
  def validate_rows(data)
    details = validation_details(data)
    details.each_with_object([]) do |(idx, row_errors), errors|
      row_label = "Riga #{idx}"
      row_errors.each do |field, messages|
        messages.each do |message|
          errors << "#{row_label}: #{message}"
        end
      end
    end
  end

  def validation_details(data)
    details = {}
    gencode_counts = Hash.new { |h, k| h[k] = [] }

    data[:rows].each do |row|
      idx = row[:_index]
      row_errors = {}
      item_code = row[ImportParser::ITEM_CODE_KEY].to_s.strip
      collection_ok = row[:_collection_id].present? || row[:_collection_description].present?

      row_errors[ImportParser::ITEM_CODE_KEY] = ['manca il codice articolo'] if item_code.blank?
      row_errors[ImportParser::NOTE_KEY] = ['manca la collezione'] unless collection_ok

      if collection_ok && item_code.present?
        gencode = ImportParser.gencode_for(row, row[:_collection_description])
        gencode_counts[gencode] << idx
      end

      details[idx] = row_errors
    end

    gencode_counts.each do |_gencode, indices|
      if indices.size > 1
        indices.each { |idx| details[idx][:gencode] = ['gencode duplicato'] }
      end
    end

    details
  end

  def classify_rows(data)
    gencodes = data[:rows].filter_map do |row|
      coll = row[:_collection_description] || row[:_collection_id]
      next nil if coll.blank?
      ImportParser.gencode_for(row, coll)
    end
    existing_gencodes = Item.where(gencode: gencodes).pluck(:gencode).to_set

    data[:rows].each_with_object({}) do |row, result|
      coll = row[:_collection_description] || row[:_collection_id]
      gencode = coll.present? ? ImportParser.gencode_for(row, coll) : nil
      result[row[:_index]] = gencode && existing_gencodes.include?(gencode) ? :update : :new
    end
  end

  def summarize(data)
    gencodes = data[:rows].map do |row|
      ImportParser.gencode_for(row, row[:_collection_description])
    end
    existing_gencodes = Item.where(gencode: gencodes).pluck(:gencode).to_set

    summary = {
      total:              data[:rows].size,
      new_items:          0,
      updated_items:      0,
      new_collections:    [],
      existing_collections: []
    }

    data[:rows].each do |row|
      gencode = ImportParser.gencode_for(row, row[:_collection_description])
      if existing_gencodes.include?(gencode)
        summary[:updated_items] += 1
      else
        summary[:new_items] += 1
      end

      if row[:_collection_new]
        summary[:new_collections] << row[:_collection_description] if row[:_collection_description].present?
      elsif row[:_collection_id].present?
        summary[:existing_collections] << row[:_collection_description] if row[:_collection_description].present?
      end
    end

    %i[new_collections existing_collections].each do |key|
      summary[key].uniq!
    end

    summary
  end
end
