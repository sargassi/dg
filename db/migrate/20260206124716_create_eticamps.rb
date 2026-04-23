class CreateEticamps < ActiveRecord::Migration[7.0]
  def change
    create_table :eticamps do |t|
      t.string :itemcode
      t.string :fabricode
      t.string :varcode
      t.string :season
      t.integer :group, default: 1

      t.timestamps
    end
  end
end
