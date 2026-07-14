class AddSourceItemToArchiveItems < ActiveRecord::Migration[7.2]
  def change
    add_reference :archive_items, :source_item, null: true, foreign_key: { to_table: :items }
  end
end
