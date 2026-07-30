class ImportParser
  require 'roo'

  ITEM_CODE_KEY   = 'Item Code:'.freeze
  FABRIC_CODE_KEY = 'Fabric code:'.freeze
  VAR_CODE_KEY    = 'var. code:'.freeze
  NOTE_KEY        = 'Note:'.freeze
  DOVE_KEY        = 'dove'.freeze

  KNOWN_HEADERS = [ITEM_CODE_KEY, FABRIC_CODE_KEY, VAR_CODE_KEY, 'Description:', 'Prezzo showroom', 'materiale', 'colour:', 'Tg.'].freeze
  TEMPLATE_HEADERS = [ITEM_CODE_KEY, FABRIC_CODE_KEY, VAR_CODE_KEY, 'Description:', 'Tg.', 'colour:', 'materiale', 'Prezzo showroom', NOTE_KEY, DOVE_KEY].freeze

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

  GCODE_KEYS = [ITEM_CODE_KEY, FABRIC_CODE_KEY, VAR_CODE_KEY].freeze

  def self.gencode_for(row, fallback_collection = nil)
    coll = row[:_collection_id] || fallback_collection
    GCODE_KEYS.map { |k| row[k].to_s.strip }.join + "_#{coll}"
  end

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
      row[:_gencode] = self.class.gencode_for(row)
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

    note_val = row[NOTE_KEY].to_s.strip
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
    dove_val = row[DOVE_KEY].to_s.strip
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
end
