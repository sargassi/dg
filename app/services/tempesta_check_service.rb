# app/services/tempesta_check_service.rb
class TempestaCheckService
  # Checks and updates the Tempesta record based on stage, assuming success/failure determines Prow finalization.
  def self.process_qr_scan(prow_id:, stage:, datex:, tempesta_id:)
    # 1. Find the Tempesta record
    chk = Tempesta.find(tempesta_id)

    # 2. Set specific stage flags
    case stage
    when "F1"
      chk.f1 = true
      chk.f1date = datex
    when "F2"
      chk.f2 = true
      chk.f2date = datex
    when "F3"
      chk.f3 = true
      chk.f3date = datex
    when "F4"
      chk.f4 = true
      chk.f4date = datex
    when "F5"
      chk.f5 = true
      chk.f5date = datex
    else
      return { success: false, message: "Invalid stage provided." }
    end

    # 3. Save changes and check for success
    if chk.save
      # 4. Check and finalize Prow status
      if has_done_tempestas?(prow_id)
        set_prow_done(prow_id, datex)
      end
      { success: true, tempesta: chk }
    else
      { success: false, errors: chk.errors.full_messages }
    end
  rescue ActiveRecord::RecordNotFound
    { success: false, message: "Tempesta record not found." }
  end

  # Class method to check if Prow has done tempestas for the given Prow ID
  def self.has_done_tempestas?(prow_id)
    Prow.find(prow_id).tempestas.where(is_done: true).exists?
  end

  # Class method to set Prow as done
  def self.set_prow_done(prow_id, datex)
    Prow.find(prow_id).update(
      done: true,
      done_date: datex
    )
  end
end