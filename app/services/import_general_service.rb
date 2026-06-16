class ImportGeneralService
  require 'roo'
  require 'rqrcode'

  FIELD_MAP = {
    'Item Code:'    => :itemcode,
    'Fabric code:'  => :fabricode,
    'var. code:'    => :varcode,
    'Description: ' => :description,
    'Fabric:'       => :fabric,
    'Tg.'           => :tg,
    'Note:'         => :note,
    'Colour:'       => :colour,
    'unit price'    => :unit_price,
    'uniti price'   => :unit_price,
    'materiale'     => :materiale
  }

  def parse(file, collection_id = nil)
    spreadsheet = Roo::Excelx.new(file)
    headers = spreadsheet.row(1)

    rows = (2..spreadsheet.last_row).map do |i|
      row = Hash[[headers, spreadsheet.row(i)].transpose]
      row[:_index] = i
      row[:_gencode] = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join + "_#{collection_id}"
      row
    end

    { headers: headers, rows: rows, collection_id: collection_id }
  end

  def save(data)
    stats = { total: 0, created: 0, updated: 0, errors: [], created_ids: [], updated_ids: [] }
    total = data[:rows].size

    data[:rows].each_with_index do |row, idx|
      stats[:total] += 1
      yield(idx + 1, total) if block_given?
      gencode = [row['Item Code:'], row['Fabric code:'], row['var. code:']].map(&:to_s).join + "_#{data[:collection_id]}"

      begin
        item = Item.find_or_initialize_by(gencode: gencode)
        new_record = item.new_record?

        FIELD_MAP.each do |header, field|
          val = row[header]
          val = val.to_f if field == :unit_price
          item[field] = val
        end

        item.gencode = gencode
        item.collection_id = data[:collection_id]
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
