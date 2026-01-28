class ImportProformasService
  require 'roo'

  def callnew(file, customer, prof)
    spreadsheet = Roo::Spreadsheet.open(file)
    spreadsheet = Roo::Excelx.new(file)
    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]

      item = Prow.new
      item.itemcode = row['Item Code:']
      item.fabricode = row['Fabric code:']
      item.varcode = row['var. code:']
      item.description = row['Description: ']
      item.tg = row['Tg.']
      item.color = row['Colour:']
      item.qty = row['Qt.']
      item.materiale = row['materiale']
      item.origine = row['Origine']
      item.code = customer
      item.lab = row['chi?']
      item.note = row['Note:']
      item.colfilcuc = row['COL. FILO CUCITO']
      item.lavaggio = row['lavaggio']
      item.dettagli = row['Dettagli:']
      item.ngemelli = row['N° gemelli']
      item.totngemelli = row['TOTALE N° gemelli']
      item.colgemelli = row['colore gemelli']
      item.fornitore = row['fornitore']
      item.tempolav = row['tempo lavaggio']
      tx = Time.now.to_i + i
      item.identifier = tx
      item.doe = row['dove']

      item.proforma_id = prof
      codex = prof.to_s + tx.to_s + row['Item Code:'] + '_' + row['Fabric code:'] + row['var. code:']
      item.qr = codex

      next unless item.save

      # tempesta iniziale
      qtx = row['Qt.'].to_i
      qtx.times do
        temp = Tempesta.new
        temp.prow_id = item.id
        temp.proforma_id = prof
        temp.save

        puts temp.inspect
      end
    end
  end

  def call(file, customer, prof)
    spreadsheet = Roo::Spreadsheet.open(file)
    spreadsheet = Roo::Excelx.new(file)
    header = spreadsheet.row(6)
    (7..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      item = Prow.new
      item.itemcode = spreadsheet.cell(i, 'A')
      item.fabricode = spreadsheet.cell(i, 'B')
      item.varcode = spreadsheet.cell(i, 'C')
      item.description = spreadsheet.cell(i, 'D')
      item.tg = spreadsheet.cell(i, 'E')
      item.color = spreadsheet.cell(i, 'F')
      item.qty = spreadsheet.cell(i, 'G')
      item.materiale = spreadsheet.cell(i, 'J')
      item.origine = spreadsheet.cell(i, 'L')
      item.doe = spreadsheet.cell(i, 'M')
      item.code = customer
      tx = Time.now.to_i + i
      item.identifier = tx
      item.proforma_id = prof
      codex = prof.to_s + tx.to_s + spreadsheet.cell(i, 'A') + '_' + spreadsheet.cell(i, 'B') + spreadsheet.cell(i, 'C')
      item.qr = codex
      next unless item.save

      # tempesta iniziale
      qtx = spreadsheet.cell(i, 'G').to_i
      qtx.times do
        temp = Tempesta.new
        temp.prow_id = item.id
        temp.proforma_id = prof
        temp.save
      end
    end
  end
end
