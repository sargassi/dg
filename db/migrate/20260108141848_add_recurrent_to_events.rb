class AddRecurrentToEvents < ActiveRecord::Migration[7.0]
  def change
    add_column :events, :recurrent, :string
    add_column :events, :boolean, :string, default: false
  end
end
