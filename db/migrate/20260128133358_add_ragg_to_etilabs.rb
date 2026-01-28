class AddRaggToEtilabs < ActiveRecord::Migration[7.0]
  def change
    add_column :etilabs, :ragg, :integer
  end
end
