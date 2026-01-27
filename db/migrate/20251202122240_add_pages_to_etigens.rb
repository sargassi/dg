class AddPagesToEtigens < ActiveRecord::Migration[7.0]
  def change
    add_column :etigens, :pages, :integer, default: 1
  end
end
