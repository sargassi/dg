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
end
