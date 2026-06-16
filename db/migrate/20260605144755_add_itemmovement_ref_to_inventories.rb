class AddItemmovementRefToInventories < ActiveRecord::Migration[7.2]
  def change
    add_reference :inventories, :itemmovement, null: true, foreign_key: true
  end
end
