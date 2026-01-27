class CreateEtigens < ActiveRecord::Migration[7.0]
  def change
    create_table :etigens do |t|
      t.string :riga1
      t.string :riga2
      t.string :riga3
      t.string :riga4
      t.string :riga5
      t.integer :qty, default: 1
      t.boolean :status, default: 0
      t.integer :group

      t.timestamps
    end
  end
end
