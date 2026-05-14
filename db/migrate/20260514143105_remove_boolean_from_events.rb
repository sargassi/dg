class RemoveBooleanFromEvents < ActiveRecord::Migration[7.2]
  def change
    remove_column :events, :boolean, :string
  end
end
