require "application_system_test_case"

class ItemsTest < ApplicationSystemTestCase
  setup do
    @item = items(:one)
  end

  test "visiting the index" do
    visit items_url
    assert_selector "h1", text: "Items"
  end

  test "should create item" do
    visit items_url
    click_on "New item"

    fill_in "Colour", with: @item.colour
    fill_in "Description", with: @item.description
    fill_in "Fabric", with: @item.fabric
    fill_in "Fabricode.string", with: @item.fabricode.string
    fill_in "Itemcode", with: @item.itemcode
    fill_in "Materiale", with: @item.materiale
    fill_in "Note", with: @item.note
    fill_in "Tg", with: @item.tg
    fill_in "Unit price", with: @item.unit_price
    fill_in "Varcode", with: @item.varcode
    click_on "Create Item"

    assert_text "Item was successfully created"
    click_on "Back"
  end

  test "should update Item" do
    visit item_url(@item)
    click_on "Edit this item", match: :first

    fill_in "Colour", with: @item.colour
    fill_in "Description", with: @item.description
    fill_in "Fabric", with: @item.fabric
    fill_in "Fabricode.string", with: @item.fabricode.string
    fill_in "Itemcode", with: @item.itemcode
    fill_in "Materiale", with: @item.materiale
    fill_in "Note", with: @item.note
    fill_in "Tg", with: @item.tg
    fill_in "Unit price", with: @item.unit_price
    fill_in "Varcode", with: @item.varcode
    click_on "Update Item"

    assert_text "Item was successfully updated"
    click_on "Back"
  end

  test "should destroy Item" do
    visit item_url(@item)
    click_on "Destroy this item", match: :first

    assert_text "Item was successfully destroyed"
  end
end
