class RenamePrezzoShowroomToVendita < ActiveRecord::Migration[7.2]
  def change
    rename_column :items, :prezzo_showroom, :vendita
  end
end
