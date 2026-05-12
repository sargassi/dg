class AddGencodeToItems < ActiveRecord::Migration[7.2]
  def change
    add_column :items, :gencode, :string
  end
end
