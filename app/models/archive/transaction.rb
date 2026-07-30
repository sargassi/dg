module Archive
  class Transaction < ApplicationRecord
    belongs_to :item, class_name: "Archive::Item", foreign_key: :archive_item_id
    belongs_to :operator, class_name: "User"

    validates :action, presence: true, inclusion: { in: %w[checkout checkin] }
    validates :date, presence: true
  end
end
