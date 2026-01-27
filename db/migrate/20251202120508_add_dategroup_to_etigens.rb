class AddDategroupToEtigens < ActiveRecord::Migration[7.0]
  def change
    add_column :etigens, :dategroup, :date
  end
end
