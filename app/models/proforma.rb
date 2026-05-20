class Proforma < ApplicationRecord
  has_many :prows
  has_many :tempestas

  scope :open, -> { where(closed: [nil, false]).order(created_at: :desc) }
end
