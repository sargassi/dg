class AddRowOrderToCollections < ActiveRecord::Migration[7.2]
  def change
    add_column :collections, :row_order, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        say "Backfilling row_order based on descending id"
        rows = select_all("SELECT id FROM collections ORDER BY id DESC")
        rows.each_with_index do |row, i|
          update("UPDATE collections SET row_order = #{i} WHERE id = #{row['id']}")
        end
      end
    end
  end
end
