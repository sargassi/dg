class AddIdentifierToProw < ActiveRecord::Migration[7.0]
  def change
    add_column :prows, :identifier, :integer
  end
end
