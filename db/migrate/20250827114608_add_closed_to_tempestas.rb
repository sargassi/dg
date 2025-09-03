class AddClosedToTempestas < ActiveRecord::Migration[7.0]
  def change
    add_column :prows, :closed, :boolean, default:false
  end
end
