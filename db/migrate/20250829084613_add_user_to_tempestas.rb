class AddUserToTempestas < ActiveRecord::Migration[7.0]
  def change
    add_reference :tempesta, :user, null: false, foreign_key: true, default: 2
  end
end
