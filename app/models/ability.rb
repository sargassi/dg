class Ability < ApplicationRecord
  has_many :user_abilities, dependent: :destroy
  has_many :users, through: :user_abilities

  validates :name, presence: true, uniqueness: true
end
