class Tempesta < ApplicationRecord
  belongs_to :prow
  belongs_to :proforma


  def self.ransackable_attributes(auth_object = nil)
      ["created_at", "f0", "f1", "f1date", "f2", "f2date", "f3", "f3date", "f4", "f4date", "f5", "f5date", "id", "order", "proforma_id", "prow_id", "qrcode", "qty", "updated_at", "user_id"]
    end
    def self.ransackable_associations(auth_object = nil)
        ["proforma", "prow"]
      end

end
