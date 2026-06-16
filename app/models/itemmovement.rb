class Itemmovement < ApplicationRecord
  belongs_to :operator, class_name: "User", optional: true
  belongs_to :source_warehouse, class_name: "Warehouse", optional: true
  belongs_to :dest_warehouse, class_name: "Warehouse", optional: true
  belongs_to :source_location, class_name: "Location", optional: true
  belongs_to :dest_location, class_name: "Location", optional: true
  has_many :itemmovements_details, dependent: :destroy
  accepts_nested_attributes_for :itemmovements_details, allow_destroy: true

  validates :indate, presence: true
  validates :dest_warehouse_id, presence: true

  validate :at_least_one_detail

  private

  def at_least_one_detail
    if itemmovements_details.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "Deve esserci almeno un dettaglio spostamento")
    end
  end
end
