class ProductsImport
  include ActiveModel::Model
  require 'roo'

  attr_accessor :file

  def initialize(attributes={})
    attributes.each { |name, value| send("#{name}=", value) }
  end

  def persisted?
    false
  end

  def open_spreadsheet
    case File.extname(file.original_filename)
    when ".csv" then Csv.new(file.path, nil, :ignore)
    when ".xls" then Roo::Excel.new(file.path, nil, :ignore)
    when ".XLS" then Roo::Excel.new(file.path, nil, :ignore)
    when ".xlsx" then Roo::Excelx.new(file.path)
    when ".XLSX" then Roo::Excelx.new(file.path)
    else raise "tipo di file nn va bene: #{file.original_filename}"
    end
  end

  def load_imported_products
    spreadsheet = open_spreadsheet
    header = spreadsheet.row(1)
    lastNum = Product.last.group.to_i + 1
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      item = Product.new
      item.itemcode = spreadsheet.cell(i,'A')
      item.fabricode = spreadsheet.cell(i,'B')
      item.varcode = spreadsheet.cell(i,'C')
      item.description = spreadsheet.cell(i,'D')
      item.tg = spreadsheet.cell(i,'E')
      item.color = spreadsheet.cell(i,'F')
      item.qty = spreadsheet.cell(i,'G')
      item.materiale = spreadsheet.cell(i,'H')
      item.group = lastNum
      item.save
    end
    # (2..spreadsheet.last_row).map do |i|
    #   row = Hash[[header, spreadsheet.row(i)].transpose]
    #   item = Product.new
    #   item.attributes = row.to_hash
    #   item
    # end
  end

  def imported_products
    @imported_products ||= load_imported_products
  end

  def save
    if imported_products
      true
    else
      imported_products.each_with_index do |item, index|
        item.errors.full_messages.each do |msg|
          errors.add :base, "Row #{index + 6}: #{msg}"
        end
      end
      false
    end
  end

end
