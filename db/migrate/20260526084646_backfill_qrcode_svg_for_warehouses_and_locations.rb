class BackfillQrcodeSvgForWarehousesAndLocations < ActiveRecord::Migration[7.2]
  require 'rqrcode'

  def up
    Warehouse.find_each do |w|
      code = "#{w.id}_#{w.code.gsub(/\s+/, '')}"
      w.update_columns(qrcode_svg: RQRCode::QRCode.new(code).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end

    Location.find_each do |l|
      code = "#{l.warehouse_id}_#{l.id}_#{l.code.gsub(/\s+/, '')}"
      l.update_columns(qrcode_svg: RQRCode::QRCode.new(code).as_svg(module_size: 6, use_path: true, viewbox: true).sub(/^<\?xml[^>]*>/, ""))
    end
  end

  def down
  end
end
