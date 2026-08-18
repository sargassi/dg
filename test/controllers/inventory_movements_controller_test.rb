require "test_helper"

class InventoryMovementsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

  test "dashboard renders" do
    get inventories_dashboard_url
    assert_response :success
  end

  test "movements renders with the itemin fixture" do
    get inventories_movements_url
    assert_response :success
  end

  test "movements filters by itemout operationtype" do
    get inventories_movements_url, params: { operationtype_id: "1" }
    assert_response :success
  end

  test "movements shows the origine badge for imported movements" do
    item = items(:one)
    Operationtype.find_or_create_by!(id: 2) { |o| o.code = "OUT"; o.description = "Uscita" }
    itemout = Itemout.new(indate: Date.current, operator: users(:one), notes: "Importazione Excel uscite", imported: true)
    itemout.itemouts_details.build(
      itemcode: item.itemcode,
      item_id: item.id,
      qty: 1,
      warehouse: warehouses(:one),
      operationtype_id: 2
    )
    itemout.save!
    StockLevel.create!(gencode: item.gencode, warehouse: warehouses(:one), location_id: 0, current_qty: 10)

    get inventories_movements_url
    assert_response :success
    assert_match "file_upload", response.body
  end

  test "movement_label renders a pdf for an itemin" do
    get inventories_movement_label_url(type: "itemin", id: itemins(:one).id)
    assert_response :success
  end

  test "movement_label redirects on invalid type" do
    get inventories_movement_label_url(type: "bogus", id: 1)
    assert_redirected_to inventories_movements_path
  end

  test "movement_modal renders for an itemin" do
    get inventories_movement_modal_url(type: "itemin", id: itemins(:one).id)
    assert_response :success
  end
end