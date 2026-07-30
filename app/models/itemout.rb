class Itemout < ApplicationRecord
  include MovementValidations

  DETAILS_ASSOC = :itemouts_details

  belongs_to :operator, class_name: "User", optional: true
  has_many :itemouts_details, dependent: :destroy
  accepts_nested_attributes_for :itemouts_details, allow_destroy: true

  validates :indate, presence: true
end
