class AddIdentityFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :name,      :string
    add_column :users, :lastname,  :string
    add_column :users, :user_type, :string, default: 'company_operator', null: false
    add_column :users, :godlike,   :boolean, default: false, null: false
  end
end
