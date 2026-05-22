class AddMoreFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :date_of_birth,  :date
    add_column :users, :date_of_hiring, :date
    add_column :users, :enabled,        :boolean, default: true, null: false
    add_column :users, :fiscal_code,    :string
    add_column :users, :vat,            :string
  end
end
