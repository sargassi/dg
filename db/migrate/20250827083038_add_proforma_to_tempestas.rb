class AddProformaToTempestas < ActiveRecord::Migration[7.0]
  def change
    add_reference :tempesta, :proforma, null: false, foreign_key: true
  end
end
