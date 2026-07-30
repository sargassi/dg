class AddQrPrintedToItems < ActiveRecord::Migration[7.2]
  def change
    add_column :items, :qr_printed, :boolean, default: false, null: false
  end
end
