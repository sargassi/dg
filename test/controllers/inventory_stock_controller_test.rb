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

  test "index shows the origine badge for imported movements" do
    item = items(:one)
    ot = Operationtype.find_by(id: 1)
    ot ||= Operationtype.create!(id: 1, code: "I")

    itemin = Itemin.new(indate: Date.current, operator: users(:one), notes: "Importazione Excel", imported: true)
    itemin.itemins_details.build(
      itemcode: item.itemcode,
      item_id: item.id,
      qty: 2,
      warehouse: warehouses(:one),
      location: locations(:one),
      operationtype_id: 1
    )
    itemin.save!
    Inventory.create!(
      operationtype: ot,
      warehouse: warehouses(:one),
      location: locations(:one),
      itemcode: item.itemcode,
      gencode: item.gencode,
      qtyavailable: 2,
      itemins_id: itemin.id,
      enabled: true
    )
    StockLevel.create!(
      gencode: item.gencode,
      warehouse: warehouses(:one),
      location: locations(:one),
      current_qty: 2
    )

    get inventories_url
    assert_response :success
    assert_match "file_upload", response.body
  end

  test "seleziona renders the catalog table with checkboxes for every item" do
    get inventories_seleziona_path
    assert_response :success
    assert_select "input[data-seleziona-target='checkbox']", count: 2
    assert_match "2 articoli", response.body
    assert_match items(:one).gencode, response.body
    assert_match items(:two).gencode, response.body
  end

  test "seleziona filters items by collection and text query" do
    get inventories_seleziona_path, params: { collection_id: collections(:one).id }
    assert_response :success
    assert_select "input[data-seleziona-target='checkbox']", count: 2

    get inventories_seleziona_path, params: { q: items(:two).itemcode }
    assert_response :success
    assert_match items(:two).gencode, response.body
    assert_no_match items(:one).gencode, response.body
  end

  test "prepare_carico stores the selection slice in session and redirects to carico with return_to" do
    item = items(:one)
    post inventories_prepare_carico_path, params: {
      selected: [{ item_id: item.id, gencode: item.gencode, collection_id: item.collection_id, qty: "3" }]
    }

    assert_response :redirect
    assert_redirected_to app_in_warehouse_path(return_to: inventories_seleziona_path)
    assert_equal(
      [{ "item_id" => item.id.to_s, "gencode" => item.gencode, "collection_id" => item.collection_id.to_s, "qty" => "3" }],
      session[:carico_prefill]
    )
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
