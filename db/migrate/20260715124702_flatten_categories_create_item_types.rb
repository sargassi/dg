class FlattenCategoriesCreateItemTypes < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE archive_items SET archive_category_id = NULL WHERE archive_category_id IN (SELECT id FROM archive_categories WHERE parent_id IS NOT NULL)"
    execute "DELETE FROM archive_categories WHERE parent_id IS NOT NULL"
    remove_column :archive_categories, :parent_id

    create_table :archive_item_types do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :archive_item_types, :name, unique: true

    add_reference :archive_items, :archive_item_type, null: true, foreign_key: { to_table: :archive_item_types }
  end

  def down
    remove_reference :archive_items, :archive_item_type, foreign_key: { to_table: :archive_item_types }
    drop_table :archive_item_types
    add_column :archive_categories, :parent_id, :integer
    add_index :archive_categories, :parent_id
  end
end
