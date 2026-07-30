module Archive
  class ItemType < ApplicationRecord
    has_many :items, class_name: "Archive::Item", foreign_key: :archive_item_type_id, dependent: :restrict_with_error

    validates :name, presence: true, uniqueness: true
  end
end
