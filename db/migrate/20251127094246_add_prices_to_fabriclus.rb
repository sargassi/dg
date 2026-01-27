class AddPricesToFabriclus < ActiveRecord::Migration[7.0]
  def change
    add_column :fabriclus, :mtkg, :decimal
    add_column :fabriclus, :mtkg20, :decimal
    add_column :fabriclus, :mtkgprezzi, :decimal
    add_column :fabriclus, :mtkg20prezzi, :decimal
    add_column :fabriclus, :perche, :string
  end
end
