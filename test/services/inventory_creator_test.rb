require "test_helper"

class InventoryCreatorTest < ActiveSupport::TestCase
  setup do
    @item = items(:one)
    @warehouse = warehouses(:one)
    @location = locations(:one)
    @operationtype = operationtypes(:one)
  end

  test "creates inbound inventory using the item's actual itemcode even when detail.itemcode is the gencode" do
    itemin = Itemin.new(indate: Date.current)
    itemin.itemins_details.build(
      itemcode: @item.gencode,
      item_id: @item.id,
      qty: 3,
      warehouse: @warehouse,
      location: @location,
      operationtype: @operationtype
    )

    records = InventoryCreator.new.call(itemin)

    assert_equal 1, records.size
    inventory = records.first
    assert_equal @item.itemcode, inventory.itemcode
    assert_equal @item.gencode, inventory.gencode
    assert_equal 3, inventory.qtyavailable
    assert_equal @operationtype.id, inventory.operationtype_id
  end

  test "creates outbound inventory using the item's actual itemcode even when detail.itemcode is wrong" do
    StockLevel.create!(gencode: @item.gencode, warehouse_id: @warehouse.id, location_id: @location.id, current_qty: 10)

    itemout = Itemout.new(indate: Date.current)
    itemout.itemouts_details.build(
      itemcode: "wrong-label",
      item_id: @item.id,
      qty: 2,
      warehouse: @warehouse,
      location: @location,
      operationtype: @operationtype
    )

    records = InventoryCreator.new.call(itemout)

    assert_equal 1, records.size
    inventory = records.first
    assert_equal @item.itemcode, inventory.itemcode
    assert_equal 2, inventory.qtyavailable
    assert_equal @operationtype.id, inventory.operationtype_id
  end

  test "creates movement inventory records and adjusts source/destination stock" do
    source_wh = warehouses(:one)
    source_loc = locations(:one)
    dest_wh = warehouses(:two)
    dest_loc = locations(:two)
    StockLevel.create!(gencode: @item.gencode, warehouse_id: source_wh.id, location_id: source_loc.id, current_qty: 5)

    inbound_op  = Operationtype.find_or_create_by!(id: 1) { |op| op.code = "carico" }
    outbound_op = Operationtype.find_or_create_by!(id: 2) { |op| op.code = "scarico" }

    itemmovement = Itemmovement.new(indate: Date.current, source_warehouse: source_wh, source_location: source_loc, dest_warehouse: dest_wh, dest_location: dest_loc)
    itemmovement.itemmovements_details.build(
      itemcode: @item.itemcode,
      item_id: @item.id,
      qty: 2,
      warehouse_id: source_wh.id,
      location_id: source_loc.id,
      operationtype_id: outbound_op.id
    )

    records = InventoryCreator.new.call(itemmovement)

    assert_equal 2, records.size
    source_record, dest_record = records

    assert_equal source_wh.id, source_record.warehouse_id
    assert_equal source_loc.id, source_record.location_id
    assert_equal outbound_op.id, source_record.operationtype_id
    assert_equal 2, source_record.qtyavailable

    assert_equal dest_wh.id, dest_record.warehouse_id
    assert_equal dest_loc.id, dest_record.location_id
    assert_equal inbound_op.id, dest_record.operationtype_id
    assert_equal 2, dest_record.qtyavailable

    assert_equal itemmovement.id, source_record.itemmovement_id
    assert_equal itemmovement.id, dest_record.itemmovement_id
  end
end
