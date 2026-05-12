class AddIndexToProformasClosed < ActiveRecord::Migration[7.0]
  def change
    add_index :proformas, :closed
    add_index :prows, :closed
  end
end