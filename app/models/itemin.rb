class Itemin < ApplicationRecord
  belongs_to :operator, class_name: "User", optional: true
  has_many :itemins_details, dependent: :destroy
  accepts_nested_attributes_for :itemins_details, allow_destroy: true

  validates :indate, presence: true

  validate :at_least_one_detail

  private

  def at_least_one_detail
    if itemins_details.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "Deve esserci almeno un dettaglio carico")
    end
  end
end
