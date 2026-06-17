class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  def after_sign_in_path_for(resource)
    if resource.respond_to?(:has_role?) && resource.has_role?(:pedone)
      app_dashboard_path
    else
      super
    end
  end

  private

  def require_ability!(ability_name)
    unless current_user.can?(ability_name)
      redirect_to root_path, alert: "Non hai i permessi per questa azione."
    end
  end

  def require_godlike!
    unless current_user.godlike?
      redirect_to root_path, alert: "Solo l'amministratore puo' accedere."
    end
  end

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
