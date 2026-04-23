class GetAvanzamentoService

  def get(prow)
    #get tempestas
    chk = []
    prow.tempestas.map do |tmp|
      chk.push(1) if tmp.f1 == true
      chk.push(1) if tmp.f2 == true
      chk.push(1) if tmp.f3 == true
      chk.push(1) if tmp.f4 == true
      chk.push(1) if tmp.f5 == true
    end

    chk.sum

  end

end
