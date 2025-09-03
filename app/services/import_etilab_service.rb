class ImportEtilabService

  require 'roo'

  def call(file)
    spreadsheet = Roo::Spreadsheet.open(file)
    spreadsheet = Roo::Excelx.new(file)
    header = spreadsheet.row(1)
    Etilab.last.present? ? lastNum = Etilab.last.group.to_i + 1 : lastnum = 1
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      item = Etilab.new
      item.itemcode = spreadsheet.cell(i,'B')
      item.fabricode = spreadsheet.cell(i,'C')
      item.varcode = spreadsheet.cell(i,'D')
      item.description = spreadsheet.cell(i,'E')
      item.tg = spreadsheet.cell(i,'F')
      item.color = spreadsheet.cell(i,'I')
      item.qty = spreadsheet.cell(i,'J')
      item.fabric = spreadsheet.cell(i,'H')
      item.materiale = spreadsheet.cell(i,'K')
      item.customer = spreadsheet.cell(i,'O')
      item.note = spreadsheet.cell(i,'G')
      item.supplier = spreadsheet.cell(i,'N')
      item.group = lastNum
      item.save
    end
  end
end
