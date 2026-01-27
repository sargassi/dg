class ImportHistoryTextService

  require 'roo'

  def call(file)
    spreadsheet = Roo::Spreadsheet.open(file)
    spreadsheet = Roo::Excelx.new(file)
    header = spreadsheet.row(1)

    (2..spreadsheet.last_row).each do |i|

      row = Hash[[header, spreadsheet.row(i)].transpose]

      chk = Fabriclu.select(:tg).map(&:tg)
      itemtg = spreadsheet.cell(i,'N') + spreadsheet.cell(i,'G') + spreadsheet.cell(i,'D') + spreadsheet.cell(i,'A')
      if !chk.include? itemtg
      item = Fabriclu.new

      item.fab = spreadsheet.cell(i,'A')
      item.var = spreadsheet.cell(i,'D')
      item.year = spreadsheet.cell(i,'N')
      item.description = spreadsheet.cell(i,'C')
      item.note = spreadsheet.cell(i,'R')
      item.color = spreadsheet.cell(i, 'G')
      item.materiale = spreadsheet.cell(i,'H')
      item.supplier = spreadsheet.cell(i,'F')
      item.mtkg = spreadsheet.cell(i,'I')
      item.mtkg20 = spreadsheet.cell(i, 'J')
      item.mtkgprezzi = spreadsheet.cell(i,'K')
      item.mtkg20prezzi = spreadsheet.cell(i,'L')
      item.perche = spreadsheet.cell(i,'M')
      item.tg = itemtg
      item.save
      end
    end
  end
end
