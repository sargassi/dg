class AddPathIconPositionToToolbarConfigs < ActiveRecord::Migration[7.2]
  def change
    add_column :toolbar_configs, :path, :string
    add_column :toolbar_configs, :icon, :string
    add_column :toolbar_configs, :position, :integer, default: 0
  end
end
