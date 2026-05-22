class UserRole < ApplicationRecord
  belongs_to :user

  validates :role, presence: true
  validates :role, uniqueness: { scope: :user_id }
end
