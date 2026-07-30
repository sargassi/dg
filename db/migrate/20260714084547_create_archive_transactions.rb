class CreateArchiveTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :archive_transactions do |t|
      t.references :archive_item, null: false, foreign_key: true
      t.string :action, null: false
      t.datetime :date, null: false
      t.references :operator, null: false, foreign_key: { to_table: :users }
      t.string :out_to
      t.text :notes

      t.timestamps
    end
  end
end
