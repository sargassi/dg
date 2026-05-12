class AddQrcodeSvgToItems < ActiveRecord::Migration[7.2]
  require 'rqrcode'

  def up
    add_column :items, :qrcode_svg, :text

    Item.find_each do |item|
      next unless item.gencode.present?
      item.update_columns(qrcode_svg: RQRCode::QRCode.new(item.gencode).as_svg(module_px_size: 6))
    end
  end

  def down
    remove_column :items, :qrcode_svg
  end
end
