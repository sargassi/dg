class AddOperationtypeToItemmovementsDetails < ActiveRecord::Migration[7.2]
  def change
    add_column :itemmovements_details, :operationtype_id, :integer
  end
end
