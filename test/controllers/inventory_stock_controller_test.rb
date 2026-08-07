require "test_helper"

class InventoryStockControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

  test "index renders without crashing when a stock gencode has no matching item" do
    StockLevel.create!(
      gencode: "UNKNOWN-GENCODE",
      warehouse: warehouses(:one),
      location: locations(:one),
      current_qty: 5
    )

    get inventories_url
    assert_response :success
    assert_match "1 articoli", response.body
  end

  test "autocomplete returns warehouse-shelf stock whose StockLevel location key is 0" do
    item = items(:one)
    ot = Operationtype.find_by(id: 1)
    ot ||= Operationtype.create!(id: 1, code: "I")

    Inventory.create!(
      operationtype: ot,
      warehouse: warehouses(:one),
      location: nil,
      itemcode: item.itemcode,
      gencode: item.gencode,
      qtyavailable: 1,
      enabled: true
    )
    StockLevel.create!(
      gencode: item.gencode,
      warehouse: warehouses(:one),
      location_id: 0,
      current_qty: 3
    )

    get autocomplete_inventories_path, params: { q: item.itemcode }
    assert_response :success
    body = JSON.parse(response.body)
    row = body.find { |r| r["gencode"] == item.gencode }
    assert row, "expected the shelf stock item in autocomplete results"
    assert_equal 3, row["qty_remaining"]
  end
end
