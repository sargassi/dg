class Rassegna < ApplicationRecord
  mount_uploader :photo, PhotoUploader
  belongs_to :account, :optional => true
  has_rich_text :description
  
  def self.ransackable_attributes(auth_object = nil)
    ["titolo", "testata","tipologia", "paese", "descrizione", "giornalista", "fotografo"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["account"]
  end

end
