require "test_helper"

class ReassignStockServiceTest < ActiveSupport::TestCase
  setup do
    @src_wh = warehouses(:one)
    @dst_wh = warehouses(:two)
    @src_loc = locations(:one)
    @dst_loc = locations(:two)
    @gencode = items(:one).gencode
  end

  test "moves stock and inventory rows between places" do
    StockLevel.create!(gencode: @gencode, warehouse: @src_wh, location: @src_loc, current_qty: 5)
    Inventory.create!(gencode: @gencode, item_id: items(:one).id, qtyavailable: 5, warehouse: @src_wh, location: @src_loc, operationtype_id: operationtypes(:one).id)

    result = ReassignStockService.call(
      gencodes: [@gencode],
      src_warehouse_id: @src_wh.id,
      src_location_id: @src_loc.id,
      dst_warehouse_id: @dst_wh.id,
      dst_location_id: @dst_loc.id
    )

    assert result.success
    assert_equal 5, result.stats[:moved]
    assert_equal 5, StockLevel.find_by!(gencode: @gencode, warehouse: @dst_wh, location: @dst_loc).current_qty
    assert_nil StockLevel.find_by(gencode: @gencode, warehouse: @src_wh, location: @src_loc)
    assert_equal @dst_wh.id, Inventory.find_by!(gencode: @gencode).warehouse_id
    assert_equal @dst_loc.id, Inventory.find_by!(gencode: @gencode).location_id
  end

  test "merges into an existing destination row" do
    StockLevel.create!(gencode: @gencode, warehouse: @src_wh, location: @src_loc, current_qty: 5)
    StockLevel.create!(gencode: @gencode, warehouse: @dst_wh, location: @dst_loc, current_qty: 3)

    result = ReassignStockService.call(
      gencodes: [@gencode],
      src_warehouse_id: @src_wh.id,
      src_location_id: @src_loc.id,
      dst_warehouse_id: @dst_wh.id,
      dst_location_id: @dst_loc.id
    )

    assert result.success
    assert_equal 8, StockLevel.find_by!(gencode: @gencode, warehouse: @dst_wh, location: @dst_loc).current_qty
  end

  test "moves all positive rows in the source warehouse when location is blank" do
    other_loc = locations(:one)
    StockLevel.create!(gencode: @gencode, warehouse: @src_wh, location: other_loc, current_qty: 2)
    StockLevel.create!(gencode: @gencode, warehouse: @src_wh, location_id: 0, current_qty: 4)

    result = ReassignStockService.call(
      gencodes: [@gencode],
      src_warehouse_id: @src_wh.id,
      src_location_id: "",
      dst_warehouse_id: @dst_wh.id,
      dst_location_id: @dst_loc.id
    )

    assert result.success
    assert_equal 6, result.stats[:moved]
    assert_equal 6, StockLevel.find_by!(gencode: @gencode, warehouse: @dst_wh, location: @dst_loc).current_qty
    assert_equal 0, StockLevel.where(gencode: @gencode, warehouse: @src_wh).count
  end

  test "requires at least one article" do
    result = ReassignStockService.call(
      gencodes: [],
      src_warehouse_id: @src_wh.id,
      dst_warehouse_id: @dst_wh.id
    )
    refute result.success
    assert_match "almeno un articolo", result.error
  end

  test "requires source and destination warehouses" do
    refute ReassignStockService.call(gencodes: [@gencode], src_warehouse_id: "", dst_warehouse_id: @dst_wh.id).success
    refute ReassignStockService.call(gencodes: [@gencode], src_warehouse_id: @src_wh.id, dst_warehouse_id: "").success
  end

  test "rejects identical origin and destination" do
    result = ReassignStockService.call(
      gencodes: [@gencode],
      src_warehouse_id: @src_wh.id,
      src_location_id: @src_loc.id,
      dst_warehouse_id: @src_wh.id,
      dst_location_id: @src_loc.id
    )
    refute result.success
    assert_match "coincidono", result.error
  end

  test "fails when no stock at source" do
    result = ReassignStockService.call(
      gencodes: [@gencode],
      src_warehouse_id: @src_wh.id,
      src_location_id: @src_loc.id,
      dst_warehouse_id: @dst_wh.id,
      dst_location_id: @dst_loc.id
    )
    refute result.success
    assert_match "Nessuna giacenza", result.error
  end
end
