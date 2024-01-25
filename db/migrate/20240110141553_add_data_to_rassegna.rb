class AddDataToRassegna < ActiveRecord::Migration[7.0]
  def change
    add_column :rassegnas, :data, :date
  end
end
