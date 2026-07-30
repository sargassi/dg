class CreateArchiveCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :archive_categories do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :archive_categories, :name, unique: true
  end
end
