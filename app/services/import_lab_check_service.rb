class ImportLabCheckService
  require 'roo'

  def call(file)
    spreadsheet = Roo::Spreadsheet.open(file)
    spreadsheet = Roo::Excelx.new(file)
    header = spreadsheet.row(1)

    Eticheck.last.present? ? lastNum = Eticheck.last.group.to_i + 1 : lastnum = 1

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      item = Eticheck.new
      item.itemcode = row['Item Code:']
      item.fabricode = row['Fabric code:']
      item.varcode = row['var. code:']
      item.description = row['Description: ']
      item.tg = row['Tg.']
      item.qt = row['Qt.'].to_i
      item.fabric = row['Fabric:']
      item.materiale = row['materiale']
      item.chi = row['chi?']
      item.dove = row['dove']
      item.group = lastNum
      item.cspediti = row['c-sepditi']
      item.save
    end

  end
end
