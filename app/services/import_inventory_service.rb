class ImportInventoryService
  require 'roo'

  def parse(file, metadata = {})
    spreadsheet = Roo::Excelx.new(file)
    headers = spreadsheet.row(1)

    rows = (2..spreadsheet.last_row).map do |i|
      row = Hash[[headers, spreadsheet.row(i)].transpose]
      row[:_index] = i
      row
    end

    {
      headers: headers,
      rows: rows,
      warehouse_id: metadata[:warehouse_id],
      location_id: metadata[:location_id],
      operationtype_id: metadata[:operationtype_id]
    }
  end

  def save(data)
    stats = { total: 0, created: 0, errors: [] }

    data[:rows].each do |row|
      stats[:total] += 1

      begin
        Inventory.create!(
          itemcode: row['Item Code:'] || row['itemcode'] || row['Item Code'],
          qtyavailable: row['Quantity'] || row['qtyavailable'] || row['QTA'] || 0,
          minstock: row['Min Stock'] || row['minstock'] || row['Min'] || 0,
          maxstock: row['Max Stock'] || row['maxstock'] || row['Max'] || 0,
          warehouse_id: data[:warehouse_id],
          location_id: data[:location_id],
          operationtype_id: data[:operationtype_id],
          enabled: true
        )
        stats[:created] += 1
      rescue => e
        stats[:errors] << { row: row[:_index], error: e.message }
      end
    end

    stats
  end
end