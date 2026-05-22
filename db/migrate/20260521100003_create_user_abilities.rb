class CreateUserAbilities < ActiveRecord::Migration[7.2]
  def change
    create_table :user_abilities do |t|
      t.references :user,       null: false, foreign_key: true
      t.references :ability,    null: false, foreign_key: true
      t.references :granted_by, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :user_abilities, [:user_id, :ability_id], unique: true
  end
end
