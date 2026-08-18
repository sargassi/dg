class AddImportedToIteminsAndItemouts < ActiveRecord::Migration[7.0]
  def up
    add_column :itemins, :imported, :boolean, default: false, null: false
    add_column :itemouts, :imported, :boolean, default: false, null: false

    Itemin.where("LOWER(notes) LIKE ?", "%importazione%").update_all(imported: true)
    Itemout.where("LOWER(notes) LIKE ?", "%importazione%").update_all(imported: true)
  end

  def down
    remove_column :itemins, :imported
    remove_column :itemouts, :imported
  end
end