class AddParentIdToArchiveCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :archive_categories, :parent_id, :integer
    add_index :archive_categories, :parent_id
    add_foreign_key :archive_categories, :archive_categories, column: :parent_id
  end
end
