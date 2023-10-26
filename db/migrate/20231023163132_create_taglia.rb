class CreateTaglia < ActiveRecord::Migration[7.0]
  def change
    create_table :taglia do |t|
      t.string :description

      t.timestamps
    end
  end
end
