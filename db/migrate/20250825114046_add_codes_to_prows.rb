class AddCodesToProws < ActiveRecord::Migration[7.0]
  def change
    add_column :prows, :itemcode, :text
    add_column :prows, :fabricode, :text
    add_column :prows, :varcode, :text
    add_column :prows, :tg, :text
    add_column :prows, :color, :text
    add_column :prows, :materiale, :text
    add_column :prows, :origine, :text
    add_column :prows, :doe, :text
  end
end
