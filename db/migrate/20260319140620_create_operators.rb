class CreateOperators < ActiveRecord::Migration[7.0]
  def change
    create_table :operators do |t|
      t.string :name
      t.string :lastname
      t.integer :role, default:0, null: false

      t.timestamps
    end
  end
end
