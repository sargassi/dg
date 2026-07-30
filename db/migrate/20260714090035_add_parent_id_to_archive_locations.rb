class AddParentIdToArchiveLocations < ActiveRecord::Migration[7.2]
  def change
    add_column :archive_locations, :parent_id, :integer
    add_index :archive_locations, :parent_id
    add_foreign_key :archive_locations, :archive_locations, column: :parent_id
  end
end
