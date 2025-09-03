class Prow < ApplicationRecord
  belongs_to :proforma
  has_many :tempestas

  #ransack stuff
  def self.ransackable_associations(auth_object = nil)
     ["proforma", "tempestas"]
  end

  def self.ransackable_attributes(auth_object = nil)
     ["code", "color", "created_at", "description", "doe", "fabricode", "id", "itemcode", "materiale", "note", "origine", "proforma_id", "qr", "qty", "tg", "updated_at", "varcode"]
  end

end
