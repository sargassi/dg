class AddIndexesToEvents < ActiveRecord::Migration[7.2]
  def change
    add_index :events, :start_time
    add_index :events, :end_time
  end
end
