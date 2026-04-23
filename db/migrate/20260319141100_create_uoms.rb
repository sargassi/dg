class CreateUoms < ActiveRecord::Migration[7.0]
  def change
    create_table :uoms do |t|
      t.string :code

      t.timestamps
    end
  end
end
