class AddNotesAndOperatorToItemins < ActiveRecord::Migration[7.2]
  def change
    add_column :itemins, :notes, :text
    add_column :itemins, :operator_id, :integer
  end
end
