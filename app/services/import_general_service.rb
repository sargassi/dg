class ImportGeneralService
  require 'roo'
  require 'rqrcode'

  KNOWN_HEADERS = ['Item Code:', 'Fabric code:', 'var. code:', 'Description:', 'Prezzo showroom', 'materiale', 'colour:', 'Tg.'].freeze

  FIELD_MAP = {
    'Item Code:'        => :itemcode,
    'Fabric code:'      => :fabricode,
    'var. code:'        => :varcode,
    'Description:'      => :description,
    'Description: '     => :description,
    'Fabric:'           => :fabric,
    'fabric:'           => :fabric,
    'Tg.'               => :tg,
    'colour:'           => :colour,
    'prezzo'            => :unit_price,
    'Prezzo showroom'   => :vendita,
    'materiale'         => :materiale
  }

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
        c = Collection.create!(description: note_val)
        row[:_collection_id] = c.id
        row[:_collection_description] = c.description
        row[:_collection_new] = true
      end
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
        w = Warehouse.create!(code: dove_val, enabled: true)
        row[:_warehouse_id] = w.id
        row[:_warehouse_code] = w.code
        row[:_warehouse_new] = true
      end
    end
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

        FIELD_MAP.each do |header, field|
          val = row[header]
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
        stats[:errors] << { row: row[:_index], error: e.message }
      end
    end

    stats
  end

  def rollback(stats)
    Item.where(id: stats[:created_ids]).destroy_all
  end
end
