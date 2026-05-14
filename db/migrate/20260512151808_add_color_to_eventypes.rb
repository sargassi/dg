class AddColorToEventypes < ActiveRecord::Migration[7.2]
  def change
    add_column :eventypes, :color, :string, default: "#3B82F6"
  end
end
