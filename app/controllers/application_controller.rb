class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  def hasDoneTempestas?(prow_id)
      prow = Prow.find(prow_id)
      qty = prow.qty.to_i
      if qty == get_no_temp(prow)
        return true
      else
        return false
      end
  end

  def get_no_temp(prow)
    if prow.tempestas.size > 0
      return prow.tempestas.where('prow_id = ? and (f1 = true and f2 = true and f3 = true and f4 = true and f5 = true)', prow.id).size
    else
      return 0
    end
  end

  def setProwDone(prow_id, today )
    prow = Prow.find(prow_id)
    prow.done = true
    prow.datedone = today
    prow.save
  end





end
