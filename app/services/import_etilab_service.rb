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
      item.tg = spreadsheet.cell(i,'H')
      item.color = spreadsheet.cell(i,'P')
      item.qty = spreadsheet.cell(i,'Q')
      item.fabric = spreadsheet.cell(i,'O')
      item.materiale = spreadsheet.cell(i,'R')
      item.customer = spreadsheet.cell(i,'V')
      item.note = spreadsheet.cell(i,'I')
      item.supplier = spreadsheet.cell(i,'N')
      item.group = lastNum
      item.save
    end
  end
end
