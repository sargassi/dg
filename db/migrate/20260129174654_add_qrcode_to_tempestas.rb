class AddQrcodeToTempestas < ActiveRecord::Migration[7.0]
  def change
    add_column :tempesta, :qrcode, :string
  end
end
