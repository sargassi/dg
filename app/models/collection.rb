class Collection < ApplicationRecord
  validates :description, presence: true, uniqueness: true
  has_many :items, dependent: :nullify
  default_scope { order(:row_order, :description) }
end
