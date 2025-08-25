class CreateTempesta < ActiveRecord::Migration[7.0]
  def change
    create_table :tempesta do |t|
      t.references :prow, null: false, foreign_key: true
      t.boolean :f0, default: true
      t.boolean :f1
      t.boolean :f2
      t.boolean :f3
      t.boolean :f4
      t.boolean :f5
      t.time :f1date
      t.time :f2date
      t.time :f3date
      t.time :f4date
      t.time :f5date

      t.timestamps
    end
  end
end
