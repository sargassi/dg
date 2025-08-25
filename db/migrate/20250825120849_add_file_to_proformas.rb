class AddFileToProformas < ActiveRecord::Migration[7.0]
  def change
    add_column :proformas, :file, :text
  end
end
