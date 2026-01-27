class AddFabricToProws < ActiveRecord::Migration[7.0]
  def change
    add_column :prows, :fabric, :text
  end
end
