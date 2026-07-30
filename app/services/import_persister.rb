class ImportPersister
  PRICE_FIELDS = %i[unit_price vendita].freeze

  def ensure_dependencies!(data)
    ActiveRecord::Base.transaction do
      collection_map = {}

      data[:rows].each do |row|
        if row[:_collection_new] && row[:_collection_description].present?
          desc = row[:_collection_description].to_s.strip.upcase
          collection_map[desc] ||= Collection.find_or_create_by!(description: desc)
          row[:_collection_id] = collection_map[desc].id
          row[:_collection_new] = false
        end
      end
    end
  end

  def save(data)
    stats = { total: 0, created: 0, updated: 0, errors: [], created_ids: [], updated_ids: [] }
    total = data[:rows].size

    data[:rows].each_with_index do |row, idx|
      stats[:total] += 1
      yield(idx + 1, total) if block_given?

      gencode = ImportParser.gencode_for(row)

      begin
        item = Item.find_or_initialize_by(gencode: gencode)
        new_record = item.new_record?

        header_map = row.keys.each_with_object({}) { |h, m| m[h.to_s.downcase.strip] = h }
        ImportParser::FIELD_MAP.each do |norm_header, field|
          raw_header = header_map[norm_header]
          next unless raw_header
          val = row[raw_header]
          val = parse_price(val) if PRICE_FIELDS.include?(field)
          item[field] = val
        end

        item.gencode = gencode
        item.collection_id = row[:_collection_id]
        item.save!

        if new_record
          stats[:created] += 1
          stats[:created_ids] << item.id
        else
          stats[:updated] += 1
          stats[:updated_ids] << item.id
        end
      rescue => e
        stats[:errors] << {
          row:    row[:_index],
          gencode: gencode,
          fields:  row.reject { |k, _| k.to_s.start_with?('_') },
          error:  e.message
        }
      end
    end

    stats
  end

  def rollback(stats)
    Item.where(id: stats[:created_ids]).destroy_all
  end

  private

  def parse_price(val)
    return 0.0 if val.blank? || val.to_s.strip.empty?
    cleaned = val.to_s
                 .gsub(/[€$£\s]/, '')
                 .gsub(',', '.')
    num = Float(cleaned)
    raise ArgumentError, "prezzo negativo non valido: #{val}" if num.negative?
    num.round(2)
  rescue ArgumentError
    raise ArgumentError, "prezzo non valido: '#{val}'"
  end
end
