class CreateSize < ActiveRecord::Migration[7.0]
  def change
    create_table :sizes do |t|
      t.string :description

      t.timestamps
    end
  end
end
