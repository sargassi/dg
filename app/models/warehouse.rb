class Warehouse < ApplicationRecord
  has_many :locations, dependent: :destroy
  validates :code, presence: true, uniqueness: true
end
