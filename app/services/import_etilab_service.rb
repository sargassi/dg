class ImportEtilabService
  require 'roo'

  def call(file)
    spreadsheet = Roo::Spreadsheet.open(file)
    spreadsheet = Roo::Excelx.new(file)
    header = spreadsheet.row(1)

    Etilab.last.present? ? lastNum = Etilab.last.ragg.to_i + 1 : lastnum = 1
    (0..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]

      item = Etilab.new
      item.itemcode = row['Item Code:']
      item.fabricode = row['Fabric code:']
      item.varcode = row['var. code:']
      item.description = row['Description: ']
      item.tg = row['Tg.']
      item.color = row['Colour:']
      item.colfilcuc = row['COL. FILO CUCITO']
      item.qty = row['Qt.']
      item.fabric = row['Fabric:']
      item.materiale = row['materiale']
      item.lab = row['chi?']
      item.customer = row['dove']
      item.note = row['Note:']
      item.supplier = row['fornitore']
      item.ragg = lastNum
      item.save
    end
  end
end
