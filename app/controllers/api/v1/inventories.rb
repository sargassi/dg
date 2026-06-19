module API
  module V1
    class Inventories < Grape::API
      include API::V1::Defaults

      resource :inventories do

        # GET /api/v1/inventories/lookup?q=gencode_or_qr_text
        params do
          requires :q, type: String, desc: "Scanned QR text or gencode"
        end
        get :lookup do
          text = params[:q].to_s.strip
          parsed = QrParser.parse(text)

          item = Item.find_by(gencode: parsed[:gencode])
          error!("Item not found", 404) unless item

          stock = StockLevel.where(gencode: parsed[:gencode]).positive.includes(:warehouse, :location)

          inbound = nil
          if parsed[:detail_id]
            detail = IteminsDetail.find_by(id: parsed[:detail_id])
            inbound = {
              warehouse_id: detail.warehouse_id,
              location_id: detail.location_id,
              warehouse: detail.warehouse&.code,
              location: detail.location&.code
            } if detail
          end

          present :item, {
            id: item.id, gencode: item.gencode, itemcode: item.itemcode,
            fabricode: item.fabricode, varcode: item.varcode,
            description: item.description, collection: item.collection&.description
          }
          present :stock, stock.map { |sl|
            { warehouse_id: sl.warehouse_id, location_id: sl.location_id,
              warehouse: sl.warehouse&.code, location: sl.location&.code,
              current_qty: sl.current_qty }
          }
          present :inbound, inbound if inbound
        end

        # POST /api/v1/inventories/inbound
        params do
          requires :details, type: Array do
            requires :gencode, type: String
            requires :qty, type: Integer, values: ->(v) { v > 0 }
            optional :warehouse_id, type: Integer
            optional :location_id, type: Integer
          end
          optional :indate, type: Date, default: -> { Date.current }
          optional :operator_id, type: Integer
          optional :notes, type: String
        end
        post :inbound do
          itemin = Itemin.new(indate: params[:indate], operator_id: params[:operator_id], notes: params[:notes])

          params[:details].each do |d|
            item = Item.find_by(gencode: d[:gencode])
            error!("Item #{d[:gencode]} not found", 404) unless item

            itemin.itemins_details.build(
              itemcode: d[:gencode], qty: d[:qty], item_id: item.id,
              warehouse_id: d[:warehouse_id], location_id: d[:location_id],
              operationtype_id: 1
            )
          end

          ActiveRecord::Base.transaction do
            itemin.save!
            CreateInventoriesFromItemin.new.call(itemin)
          end

          present :id, itemin.id
          present :details_count, itemin.itemins_details.size
        end

        # POST /api/v1/inventories/outbound
        params do
          requires :details, type: Array do
            requires :gencode, type: String
            requires :qty, type: Integer, values: ->(v) { v > 0 }
            requires :warehouse_id, type: Integer
            requires :location_id, type: Integer
          end
          optional :indate, type: Date, default: -> { Date.current }
          optional :operator_id, type: Integer
        end
        post :outbound do
          params[:details].each do |d|
            sl = StockLevel.find_by(gencode: d[:gencode], warehouse_id: d[:warehouse_id], location_id: d[:location_id] || 0)
            error!("Insufficient stock for #{d[:gencode]} at WH##{d[:warehouse_id]}/LOC##{d[:location_id]}: available #{sl&.current_qty || 0}, requested #{d[:qty]}", 422) unless sl && sl.current_qty >= d[:qty]
          end

          itemout = Itemout.new(indate: params[:indate], operator_id: params[:operator_id])

          params[:details].each do |d|
            item = Item.find_by(gencode: d[:gencode])
            error!("Item #{d[:gencode]} not found", 404) unless item

            itemout.itemouts_details.build(
              itemcode: d[:gencode], qty: d[:qty], item_id: item.id,
              warehouse_id: d[:warehouse_id], location_id: d[:location_id],
              operationtype_id: 2
            )
          end

          ActiveRecord::Base.transaction do
            itemout.save!
            CreateInventoriesFromItemout.new.call(itemout)
          end

          present :id, itemout.id
          present :details_count, itemout.itemouts_details.size
        end

        # POST /api/v1/inventories/transfer
        params do
          requires :details, type: Array do
            requires :gencode, type: String
            requires :qty, type: Integer, values: ->(v) { v > 0 }
            requires :source_warehouse_id, type: Integer
            requires :source_location_id, type: Integer
            requires :dest_warehouse_id, type: Integer
            requires :dest_location_id, type: Integer
          end
          optional :indate, type: Date, default: -> { Date.current }
          optional :operator_id, type: Integer
        end
        post :transfer do
          items_by_gencode = Item.where(gencode: params[:details].map { |d| d[:gencode] }).index_by(&:gencode)

          params[:details].group_by { |d|
            [d[:source_warehouse_id], d[:source_location_id],
             d[:dest_warehouse_id], d[:dest_location_id]]
          }.each do |(src_wh, src_loc, dst_wh, dst_loc), group|
            itemmovement = Itemmovement.new(
              indate: params[:indate], operator_id: params[:operator_id],
              source_warehouse_id: src_wh, source_location_id: src_loc,
              dest_warehouse_id: dst_wh, dest_location_id: dst_loc
            )

            group.each do |d|
              item = items_by_gencode[d[:gencode]]
              error!("Item #{d[:gencode]} not found", 404) unless item

              sl = StockLevel.find_by(gencode: d[:gencode], warehouse_id: src_wh, location_id: src_loc || 0)
              error!("Insufficient stock for #{d[:gencode]} at WH##{src_wh}/LOC##{src_loc}", 422) unless sl && sl.current_qty >= d[:qty]

              itemmovement.itemmovements_details.build(
                itemcode: d[:gencode], qty: d[:qty], item_id: item.id,
                warehouse_id: src_wh, location_id: src_loc,
                operationtype_id: 2
              )
            end

            ActiveRecord::Base.transaction do
              itemmovement.save!
              CreateInventoriesFromItemmovement.new.call(itemmovement)
            end
          end

          present :success, true
        end

        # GET /api/v1/inventories/stock
        params do
          optional :warehouse_id, type: Integer
          optional :location_id, type: Integer
          optional :gencode, type: String
        end
        get :stock do
          stock = StockLevel.positive.includes(:warehouse, :location)
          stock = stock.where(warehouse_id: params[:warehouse_id]) if params[:warehouse_id]
          stock = stock.where(location_id: params[:location_id] || 0) if params[:location_id]
          stock = stock.where(gencode: params[:gencode]) if params[:gencode]

          present stock, with: API::V1::Entities::InventoryDetail
        end
      end
    end
  end
end
