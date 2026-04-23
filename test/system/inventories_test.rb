require "application_system_test_case"

class InventoriesTest < ApplicationSystemTestCase
  setup do
    @inventory = inventories(:one)
  end

  test "visiting the index" do
    visit inventories_url
    assert_selector "h1", text: "Inventories"
  end

  test "should create inventory" do
    visit inventories_url
    click_on "New inventory"

    check "Enabled" if @inventory.enabled
    fill_in "Itemcode", with: @inventory.itemcode
    fill_in "Itemins", with: @inventory.itemins_id
    fill_in "Itemouts", with: @inventory.itemouts_id
    fill_in "Location", with: @inventory.location_id
    fill_in "Maxstock", with: @inventory.maxstock
    fill_in "Minstock", with: @inventory.minstock
    fill_in "Operationtype", with: @inventory.operationtype_id
    fill_in "Qtyavailable", with: @inventory.qtyavailable
    fill_in "Warehouse", with: @inventory.warehouse_id
    click_on "Create Inventory"

    assert_text "Inventory was successfully created"
    click_on "Back"
  end

  test "should update Inventory" do
    visit inventory_url(@inventory)
    click_on "Edit this inventory", match: :first

    check "Enabled" if @inventory.enabled
    fill_in "Itemcode", with: @inventory.itemcode
    fill_in "Itemins", with: @inventory.itemins_id
    fill_in "Itemouts", with: @inventory.itemouts_id
    fill_in "Location", with: @inventory.location_id
    fill_in "Maxstock", with: @inventory.maxstock
    fill_in "Minstock", with: @inventory.minstock
    fill_in "Operationtype", with: @inventory.operationtype_id
    fill_in "Qtyavailable", with: @inventory.qtyavailable
    fill_in "Warehouse", with: @inventory.warehouse_id
    click_on "Update Inventory"

    assert_text "Inventory was successfully updated"
    click_on "Back"
  end

  test "should destroy Inventory" do
    visit inventory_url(@inventory)
    click_on "Destroy this inventory", match: :first

    assert_text "Inventory was successfully destroyed"
  end
end
