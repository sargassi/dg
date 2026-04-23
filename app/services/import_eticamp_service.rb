class ImportEticampService
  require 'roo'

  def call(file, season)
    spreadsheet = Roo::Spreadsheet.open(file)
    spreadsheet = Roo::Excelx.new(file)
    header = spreadsheet.row(1)

    Eticamp.last.present? ? lastNum = Etilab.last.group.to_i + 1 : lastnum = 1
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      item = Eticamp.new
      item.itemcode = row['Item Code:']
      item.fabricode = row['Fabric code:']
      item.varcode = row['var. code:']
      item.season = season
      item.group = lastNum
      item.save

    end
  end
end
