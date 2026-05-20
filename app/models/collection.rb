class Collection < ApplicationRecord
  validates :description, presence: true, uniqueness: true
end
