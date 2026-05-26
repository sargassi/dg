class AddQrcodeSvgToWarehousesAndLocations < ActiveRecord::Migration[7.2]
  require 'rqrcode'

  def up
    add_column :warehouses, :qrcode_svg, :text
    add_column :locations, :qrcode_svg, :text

    Warehouse.find_each do |w|
      next unless w.code.present?
      w.update_columns(qrcode_svg: RQRCode::QRCode.new(w.code).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end

    Location.find_each do |l|
      code = "#{l.warehouse_id}_#{l.id}"
      l.update_columns(qrcode_svg: RQRCode::QRCode.new(code).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end
  end

  def down
    remove_column :warehouses, :qrcode_svg
    remove_column :locations, :qrcode_svg
  end
end
