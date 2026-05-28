class DropOperators < ActiveRecord::Migration[7.2]
  def up
    remove_foreign_key :itemins, :operators, if_exists: true
    remove_foreign_key :itemouts, :operators, if_exists: true
    remove_column :itemins, :operator_id, if_exists: true
    remove_column :itemouts, :operator_id, if_exists: true
    drop_table :operators, if_exists: true
  end

  def down
    create_table :operators do |t|
      t.string :name
      t.string :lastname
      t.integer :role, default: 0, null: false
      t.timestamps
    end
    add_column :itemins, :operator_id, :integer, null: false
    add_column :itemouts, :operator_id, :integer, null: false
    add_index :itemins, :operator_id
    add_index :itemouts, :operator_id
    add_foreign_key :itemins, :operators
    add_foreign_key :itemouts, :operators
  end
end
