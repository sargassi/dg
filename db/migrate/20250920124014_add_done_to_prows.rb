class AddDoneToProws < ActiveRecord::Migration[7.0]
  def change
    add_column :prows, :done, :boolean, default: false
    add_column :prows, :datedone, :time
  end
end
