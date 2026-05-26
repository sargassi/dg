class AddFieldsToItemouts < ActiveRecord::Migration[7.2]
  def change
    add_column :itemouts, :warehouse_id, :integer
    add_column :itemouts, :location_id, :integer
    add_column :itemouts, :operationtype_id, :integer
    add_column :itemouts, :notes, :text
    add_column :itemouts, :operator_id, :integer
  end
end
