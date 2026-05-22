class UserAbility < ApplicationRecord
  belongs_to :user
  belongs_to :ability
  belongs_to :granted_by, class_name: 'User'

  validates :user_id, uniqueness: { scope: :ability_id }
end
