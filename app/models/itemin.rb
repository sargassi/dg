class Itemin < ApplicationRecord
  include MovementValidations

  DETAILS_ASSOC = :itemins_details

  belongs_to :operator, class_name: "User", optional: true
  has_many :itemins_details, dependent: :destroy
  accepts_nested_attributes_for :itemins_details, allow_destroy: true

  validates :indate, presence: true
end
