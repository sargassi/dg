class AddPrezzoShowroomToItems < ActiveRecord::Migration[7.2]
  def change
    add_column :items, :prezzo_showroom, :decimal
  end
end
