class CreateToolbarConfigs < ActiveRecord::Migration[7.2]
  def change
    create_table :toolbar_configs do |t|
      t.string :section, null: false
      t.string :item_label, null: false
      t.boolean :visible, default: true, null: false

      t.timestamps
    end

    add_index :toolbar_configs, [:section, :item_label], unique: true
  end
end
