class AddNoteToEtilabs < ActiveRecord::Migration[7.0]
  def change
    add_column :etilabs, :note, :string
  end
end
