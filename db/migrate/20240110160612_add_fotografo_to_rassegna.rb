class AddFotografoToRassegna < ActiveRecord::Migration[7.0]
  def change
    add_column :rassegnas, :fotografo, :string
  end
end
