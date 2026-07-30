class Itemmovement < ApplicationRecord
  include MovementValidations

  DETAILS_ASSOC = :itemmovements_details

  belongs_to :operator, class_name: "User", optional: true
  belongs_to :source_warehouse, class_name: "Warehouse", optional: true
  belongs_to :dest_warehouse, class_name: "Warehouse", optional: true
  belongs_to :source_location, class_name: "Location", optional: true
  belongs_to :dest_location, class_name: "Location", optional: true
  has_many :itemmovements_details, dependent: :destroy
  accepts_nested_attributes_for :itemmovements_details, allow_destroy: true

  validates :indate, presence: true
  validates :dest_warehouse_id, presence: true
  validates :source_warehouse_id, presence: true
end
