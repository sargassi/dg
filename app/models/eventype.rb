class Eventype < ApplicationRecord
  has_many :events, dependent: :restrict_with_error

  validates :color, format: { with: /\A#([0-9a-f]{3}){1,2}\z/i, allow_blank: true, message: "must be a valid hex color" }
end
