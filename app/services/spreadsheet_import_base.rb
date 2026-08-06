class SpreadsheetImportBase
  require 'roo'

  def parse(file, metadata = {})
    @metadata = metadata
    spreadsheet = Roo::Excelx.new(file)
    header_row = find_header_row(spreadsheet)
    headers = spreadsheet.row(header_row)

    rows = ((header_row + 1)..spreadsheet.last_row).map do |i|
      row = Hash[[headers, spreadsheet.row(i)].transpose]
      row[:_index] = i
      validate_row(row)
      after_row(row)
      row
    end

    { headers: headers, rows: rows }.merge(extra_metadata)
  end

  def find_header_row(spreadsheet)
    (1..spreadsheet.last_row).each do |i|
      row = spreadsheet.row(i)
      next if row.nil? || row.empty?
      matches = known_headers.count { |h| row.any? { |cell| cell.to_s.strip.downcase == h.downcase } }
      return i if matches >= 2
    end
    1
  end

  def cell(row, *keys)
    keys.each do |k|
      return row[k] if row.key?(k)
      match = row.find { |key, _| key.to_s.downcase.strip == k.to_s.downcase.strip }
      return match[1] if match
    end
    nil
  end

  def find_or_create_warehouse(code)
    return nil if code.to_s.strip.blank?
    Warehouse.find_or_create_by!(code: code.to_s.strip) { |wh| wh.enabled = true }
  end

  def find_or_create_collection(description)
    return nil if description.to_s.strip.blank?
    Collection.find_or_create_by!(description: description.to_s.strip)
  end

  def extract_error(error)
    if error.respond_to?(:record) && error.record
      error.record.errors.full_messages.join(", ")
    elsif error.message.include?("record_invalid")
      "Validazione fallita"
    else
      error.message
    end
  end

  private

  def known_headers
    raise NotImplementedError, "#{self.class} must implement known_headers"
  end

  def validate_row(_row)
    raise NotImplementedError, "#{self.class} must implement validate_row"
  end

  def after_row(_row)
  end

  def extra_metadata
    {}
  end
end
