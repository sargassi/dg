class AddGencodeToInventories < ActiveRecord::Migration[7.2]
  def change
    add_column :inventories, :gencode, :string
  end
end
