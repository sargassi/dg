class ImportGeneralService
  require 'roo'
  require 'rqrcode'

  KNOWN_HEADERS = ['Item Code:', 'Fabric code:', 'var. code:', 'Description:', 'Prezzo showroom', 'materiale', 'colour:', 'Tg.'].freeze
  TEMPLATE_HEADERS = ['Item Code:', 'Fabric code:', 'var. code:', 'Description:', 'Tg.', 'colour:', 'materiale', 'Prezzo showroom', 'Note:', 'dove'].freeze

  FIELD_MAP = {
    'item code:'      => :itemcode,
    'fabric code:'    => :fabricode,
    'var. code:'      => :varcode,
    'description:'    => :description,
    'fabric:'         => :fabric,
    'tg.'             => :tg,
    'colour:'         => :colour,
    'prezzo showroom' => :vendita,
    'prezzo'          => :unit_price,
    'materiale'       => :materiale
  }.freeze

  def parse(file, metadata = {})
    override_collection_id = metadata[:collection_id].to_i if metadata[:collection_id].present?
    spreadsheet = Roo::Excelx.new(file)
    header_row = find_header_row(spreadsheet)
    headers = spreadsheet.row(header_row)

    rows = ((header_row + 1)..spreadsheet.last_row).map do |i|
      row = Hash[[headers, spreadsheet.row(i)].transpose]
      row[:_index] = i
      resolve_collection(row, override_collection_id: override_collection_id)
      resolve_warehouse(row)
      row[:_gencode] = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join + "_#{row[:_collection_id]}"
      row
    end

    { headers: headers, rows: rows }
  end

  def find_header_row(spreadsheet)
    (1..spreadsheet.last_row).each do |i|
      row = spreadsheet.row(i)
      next if row.nil? || row.empty?
      matches = KNOWN_HEADERS.count { |h| row.any? { |cell| cell.to_s.strip == h } }
      return i if matches >= 2
    end
    1
  end

  def normalize_header(header)
    header.to_s.downcase.strip
  end

  def resolve_collection(row, override_collection_id: nil)
    if override_collection_id
      c = Collection.find(override_collection_id)
      row[:_collection_id] = c.id
      row[:_collection_description] = c.description
      row[:_collection_new] = false
      return
    end

    note_val = row['Note:'].to_s.strip
    if note_val.present?
      existing_c = Collection.find_by(description: note_val)
      if existing_c
        row[:_collection_id] = existing_c.id
        row[:_collection_description] = existing_c.description
        row[:_collection_new] = false
      else
        row[:_collection_id] = nil
        row[:_collection_description] = note_val
        row[:_collection_new] = true
      end
    else
      row[:_collection_id] = nil
      row[:_collection_description] = nil
      row[:_collection_new] = false
    end
  end

  def resolve_warehouse(row)
    dove_val = row['dove'].to_s.strip
    if dove_val.present?
      existing_w = Warehouse.find_by(code: dove_val)
      if existing_w
        row[:_warehouse_id] = existing_w.id
        row[:_warehouse_code] = existing_w.code
        row[:_warehouse_new] = false
      else
        row[:_warehouse_id] = nil
        row[:_warehouse_code] = dove_val
        row[:_warehouse_new] = true
      end
    else
      row[:_warehouse_id] = nil
      row[:_warehouse_code] = nil
      row[:_warehouse_new] = false
    end
  end

  def ensure_dependencies!(data)
    ActiveRecord::Base.transaction do
      collection_map = {}
      warehouse_map = {}

      data[:rows].each do |row|
        if row[:_collection_new] && row[:_collection_description].present?
          desc = row[:_collection_description]
          collection_map[desc] ||= Collection.create!(description: desc)
          row[:_collection_id] = collection_map[desc].id
          row[:_collection_new] = false
        end

        if row[:_warehouse_new] && row[:_warehouse_code].present?
          code = row[:_warehouse_code]
          warehouse_map[code] ||= Warehouse.create!(code: code, enabled: true)
          row[:_warehouse_id] = warehouse_map[code].id
          row[:_warehouse_code] = warehouse_map[code].code
          row[:_warehouse_new] = false
        end
      end
    end
  end

  def classify_rows(data)
    gencodes = data[:rows].filter_map do |row|
      coll_id = row[:_collection_id] || row[:_collection_description]
      next nil if coll_id.blank?
      [row['Item Code:'].to_s.strip, row['Fabric code:'].to_s.strip, row['var. code:'].to_s.strip].join + "_#{coll_id}"
    end
    existing_gencodes = Item.where(gencode: gencodes).pluck(:gencode).to_set

    data[:rows].each_with_object({}) do |row, result|
      coll_id = row[:_collection_id] || row[:_collection_description]
      gencode = coll_id.present? ? [row['Item Code:'].to_s.strip, row['Fabric code:'].to_s.strip, row['var. code:'].to_s.strip].join + "_#{coll_id}" : nil
      result[row[:_index]] = existing_gencodes.include?(gencode) ? :update : :new
    end
  end

  def validation_details(data)
    details = {}
    gencode_counts = Hash.new { |h, k| h[k] = [] }

    data[:rows].each do |row|
      idx = row[:_index]
      row_errors = {}
      item_code = row['Item Code:'].to_s.strip
      collection_ok = row[:_collection_id].present? || row[:_collection_description].present?

      row_errors['Item Code:'] = ['manca il codice articolo'] if item_code.blank?
      row_errors['Note:'] = ['manca la collezione'] unless collection_ok

      if collection_ok && item_code.present?
        coll_id = row[:_collection_id] || row[:_collection_description]
        gencode = [item_code, row['Fabric code:'].to_s.strip, row['var. code:'].to_s.strip].join + "_#{coll_id}"
        gencode_counts[gencode] << idx
      end

      details[idx] = row_errors
    end

    gencode_counts.each do |gencode, indices|
      if indices.size > 1
        indices.each { |idx| details[idx][:gencode] = ['gencode duplicato'] }
      end
    end

    details
  end

  def validate_rows(data)
    details = validation_details(data)
    errors = []

    details.each do |idx, row_errors|
      row_label = "Riga #{idx}"
      row_errors.each do |field, messages|
        messages.each do |message|
          errors << "#{row_label}: #{message}"
        end
      end
    end

    errors
  end

  def summarize(data)
    gencodes = data[:rows].map do |row|
      [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join + "_#{row[:_collection_id]}"
    end
    existing_gencodes = Item.where(gencode: gencodes).pluck(:gencode).to_set

    summary = {
      total: data[:rows].size,
      new_items: 0,
      updated_items: 0,
      new_collections: [],
      existing_collections: [],
      new_warehouses: [],
      existing_warehouses: []
    }

    data[:rows].each do |row|
      gencode = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join + "_#{row[:_collection_id]}"
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

      if row[:_warehouse_new]
        summary[:new_warehouses] << row[:_warehouse_code] if row[:_warehouse_code].present?
      elsif row[:_warehouse_id].present?
        summary[:existing_warehouses] << row[:_warehouse_code] if row[:_warehouse_code].present?
      end
    end

    summary[:new_collections].uniq!
    summary[:existing_collections].uniq!
    summary[:new_warehouses].uniq!
    summary[:existing_warehouses].uniq!

    summary
  end

  def save(data)
    stats = { total: 0, created: 0, updated: 0, errors: [], created_ids: [], updated_ids: [] }
    total = data[:rows].size

    data[:rows].each_with_index do |row, idx|
      stats[:total] += 1
      yield(idx + 1, total) if block_given?

      coll_id = row[:_collection_id]
      gencode = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join + "_#{coll_id}"

      begin
        item = Item.find_or_initialize_by(gencode: gencode)
        new_record = item.new_record?

        header_map = row.keys.each_with_object({}) { |h, m| m[normalize_header(h)] = h }
        FIELD_MAP.each do |norm_header, field|
          raw_header = header_map[norm_header]
          next unless raw_header
          val = row[raw_header]
          val = val.to_f.round if %i[unit_price vendita].include?(field)
          item[field] = val
        end

        item.gencode = gencode
        item.collection_id = coll_id
        item.qrcode_svg = RQRCode::QRCode.new(gencode).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, "")
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
          row: row[:_index],
          gencode: gencode,
          fields: row.reject { |k, _| k.to_s.start_with?('_') },
          error: e.message
        }
      end
    end

    stats
  end

  def rollback(stats)
    Item.where(id: stats[:created_ids]).destroy_all
  end
end
