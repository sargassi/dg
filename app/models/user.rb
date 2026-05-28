class User < ApplicationRecord
  has_many :api_tokens
  has_many :user_roles,    dependent: :destroy
  has_many :user_abilities, dependent: :destroy
  has_many :abilities,     through: :user_abilities
  has_many :itemins
  has_many :itemouts
  has_many :tempestas
  has_many :events, dependent: :nullify

  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :lockable, :trackable

  validates :user_type, inclusion: { in: %w[company_operator customer supplier] }
  validates :name, presence: true, if: :company_operator?

  def company_operator?
    user_type == 'company_operator'
  end

  def godlike?
    godlike
  end

  def roles
    user_roles.pluck(:role)
  end

  def has_role?(role_name)
    roles.include?(role_name.to_s)
  end

  def can?(ability_name)
    godlike? || abilities.exists?(name: ability_name)
  end

  def grant_ability(ability, granted_by:)
    user_abilities.find_or_create_by!(ability: ability, granted_by: granted_by)
  end

  def revoke_ability(ability)
    user_abilities.find_by(ability: ability)&.destroy
  end
end
