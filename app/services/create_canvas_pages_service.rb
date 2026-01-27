class CreateCanvasPagesService

  def init(pages, date, group)

      nmbr = pages.to_i * 24
      nmbr.times do
        x = Etigen.new
        x.status = true
        x.qty = 1
        x.group = group.to_i
        x.dategroup = date
        x.save
      end
  end

end
