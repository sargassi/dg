class Itemout < ApplicationRecord
  belongs_to :operator, class_name: "User", optional: true
  has_many :itemouts_details, dependent: :destroy
  accepts_nested_attributes_for :itemouts_details, allow_destroy: true

  validates :indate, presence: true

  validate :at_least_one_detail

  private

  def at_least_one_detail
    if itemouts_details.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "Deve esserci almeno un dettaglio scarico")
    end
  end
end
