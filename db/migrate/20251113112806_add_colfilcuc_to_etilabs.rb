class AddColfilcucToEtilabs < ActiveRecord::Migration[7.0]
  def change
    add_column :etilabs, :colfilcuc, :string
    add_column :etilabs, :lab, :string
  end
end
