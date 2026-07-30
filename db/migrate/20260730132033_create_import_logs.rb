class CreateImportLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :import_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :file_name
      t.integer :total_rows
      t.integer :created_count
      t.integer :updated_count
      t.integer :error_count
      t.text :created_ids
      t.text :updated_ids
      t.text :error_details
      t.string :status, default: 'pending'
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end
