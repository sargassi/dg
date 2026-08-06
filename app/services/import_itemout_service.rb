class ImportItemoutService < SpreadsheetImportBase
  def known_headers
    ['Item Code:', 'Fabric code:', 'var. code:', 'dove', 'esce data:', 'venduto', 'destinazione:'].freeze
  end

  def validate_row(row)
    itemcode = cell(row, 'Item Code:', 'itemcode')
    if itemcode.blank?
      row[:_valid] = false
      row[:_error] = "Item code mancante"
      return
    end

    fabricode = cell(row, 'Fabric code:', 'fabricode')
    varcode = cell(row, 'var. code:', 'varcode')

    item = if fabricode.present? && varcode.present?
      Item.find_by(itemcode: itemcode, fabricode: fabricode, varcode: varcode)
    elsif varcode.present?
      Item.find_by(itemcode: itemcode, varcode: varcode)
    else
      Item.find_by(gencode: itemcode) || Item.find_by(itemcode: itemcode)
    end

    unless item
      row[:_valid] = false
      row[:_error] = "Articolo #{itemcode} non trovato"
      return
    end

    row[:_valid] = true
    row[:_item_id] = item.id
    row[:_itemcode] = item.itemcode
    row[:_gencode] = item.gencode

    esce_data = cell(row, 'esce data:', 'Esce data :')
    if esce_data.blank?
      row[:_valid] = false
      row[:_error] = "Data uscita mancante"
      return
    end

    row[:_date] = if esce_data.is_a?(Date) || esce_data.is_a?(DateTime) || esce_data.is_a?(Time)
      esce_data.to_date
    else
      begin
        Date.strptime(esce_data.to_s.strip, '%d/%m/%Y')
      rescue ArgumentError
        row[:_valid] = false
        row[:_error] = "Data #{esce_data} non valida (formato DD/MM/YYYY)"
        return
      end
    end

    row[:_qty] = 1
    row[:_destinazione] = cell(row, 'destinazione:', 'destinazione').to_s.strip
  end

  def save(data, user = nil)
    stats = { total: data[:rows].size, created: 0, errors: [], invalid: [], itemouts: [] }

    valid_rows = data[:rows].select { |r| r[:_valid] }
    invalid_rows = data[:rows].reject { |r| r[:_valid] }

    invalid_rows.each do |row|
      stats[:invalid] << { itemcode: cell(row, 'Item Code:', 'itemcode'), row: row[:_index], error: row[:_error] }
    end

    return stats if valid_rows.empty?

    rows_with_warehouse = valid_rows.select do |row|
      dove = cell(row, 'dove').to_s.strip
      if dove.blank?
        stats[:invalid] << { itemcode: row[:_itemcode], row: row[:_index], error: "Magazzino (dove) mancante" }
        next false
      end
      row[:_warehouse_id] = find_or_create_warehouse(dove).id
      true
    end

    return stats if rows_with_warehouse.empty?

    ActiveRecord::Base.transaction do
      rows_with_warehouse.group_by { |r| r[:_date] }.each do |date, date_rows|
        itemout = Itemout.new(indate: date, operator_id: user&.id, notes: "Importazione Excel uscite")
        op_type_id = 2

        date_rows.each do |row|
          note_val = cell(row, 'Note:', 'note').to_s.strip
          collection_id = nil
          if note_val.present?
            collection_id = find_or_create_collection(note_val).id
          end

          itemout.itemouts_details.build(
            itemcode: row[:_itemcode],
            item_id: row[:_item_id],
            qty: row[:_qty],
            warehouse_id: row[:_warehouse_id],
            collection_id: collection_id,
            operationtype_id: op_type_id
          )
        end

        itemout.save!
        InventoryCreator.new.call(itemout)

        stats[:itemouts] << { id: itemout.id, date: date, details: date_rows.size }
        stats[:created] += date_rows.size
      end
    end

    stats
  rescue => e
    stats[:errors] << { row: 0, error: extract_error(e) }
    stats
  end
end
