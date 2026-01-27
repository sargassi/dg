class CreateEventypes < ActiveRecord::Migration[7.0]
  def change
    create_table :eventypes do |t|
      t.string :name
      t.boolean :enabled, default: true

      t.timestamps
    end
  end
end
