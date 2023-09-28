class CreateZone < ActiveRecord::Migration[7.0]
  def change
    create_table :zones do |t|
      t.string :name

      t.timestamps
    end
  end
end
