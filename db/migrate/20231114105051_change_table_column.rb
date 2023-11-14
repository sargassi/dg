class ChangeTableColumn < ActiveRecord::Migration[7.0]
  def change
    change_column :products, :description, :string
  end
end
