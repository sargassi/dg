class ChangeDataInToProformas < ActiveRecord::Migration[7.0]
  def change
    change_column :proformas, :data_in, :date
  end
end
