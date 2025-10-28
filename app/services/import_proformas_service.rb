class ImportProformasService

  require 'roo'

  def call(file, customer, prof)
    spreadsheet = Roo::Spreadsheet.open(file)
    spreadsheet = Roo::Excelx.new(file)
    header = spreadsheet.row(6)
    (7..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      item = Prow.new
      item.itemcode = spreadsheet.cell(i,'A')
      item.fabricode = spreadsheet.cell(i,'B')
      item.varcode = spreadsheet.cell(i,'C')
      item.description = spreadsheet.cell(i,'D')
      item.tg = spreadsheet.cell(i,'E')
      item.color = spreadsheet.cell(i,'F')
      item.qty = spreadsheet.cell(i,'G')
      item.materiale = spreadsheet.cell(i,'J')
      item.origine = spreadsheet.cell(i,'L')
      item.doe = spreadsheet.cell(i,'M')
      item.code = customer
      tx = Time.now.to_i + i
      item.identifier = tx
      item.proforma_id = prof
      codex = prof.to_s + tx.to_s + spreadsheet.cell(i,'A') + '_' + spreadsheet.cell(i,'B') + spreadsheet.cell(i,'C')
      item.qr = codex
      if item.save

      #tempesta iniziale
      qtx = spreadsheet.cell(i,'G').to_i
      qtx.times do
        temp = Tempesta.new
        temp.prow_id = item.id
        temp.proforma_id = prof
        temp.save
      end
      end

    end
  end
end
