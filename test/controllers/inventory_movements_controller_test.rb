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