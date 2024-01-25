class AddPagineaToRassegna < ActiveRecord::Migration[7.0]
  def change
    add_column :rassegnas, :paginea, :integer
  end
end