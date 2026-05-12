class Item < ApplicationRecord

  def self.ransackable_attributes(auth_object = nil)
         ["itemcode", "varcode", "description", "tg", "fabric", "colour", "unit_price", "materiale", "note"]
  end

  def self.ransackable_associations(auth_object = nil)
         []
  end

  has_many_attached :pictures

end
