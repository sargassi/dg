require "application_system_test_case"

class ProductsTest < ApplicationSystemTestCase
  setup do
    @product = products(:one)
  end

  test "visiting the index" do
    visit products_url
    assert_selector "h1", text: "Products"
  end

  test "should create product" do
    visit products_url
    click_on "New product"

    fill_in "Color", with: @product.color
    fill_in "Description", with: @product.description
    fill_in "Fabric", with: @product.fabric
    fill_in "Fabricode", with: @product.fabricode
    fill_in "Itemcode", with: @product.itemcode
    fill_in "Materiale", with: @product.materiale
    fill_in "Note", with: @product.note
    fill_in "Prodcode", with: @product.prodcode
    fill_in "Tg", with: @product.tg
    fill_in "Varcode", with: @product.varcode
    click_on "Create Product"

    assert_text "Product was successfully created"
    click_on "Back"
  end

  test "should update Product" do
    visit product_url(@product)
    click_on "Edit this product", match: :first

    fill_in "Color", with: @product.color
    fill_in "Description", with: @product.description
    fill_in "Fabric", with: @product.fabric
    fill_in "Fabricode", with: @product.fabricode
    fill_in "Itemcode", with: @product.itemcode
    fill_in "Materiale", with: @product.materiale
    fill_in "Note", with: @product.note
    fill_in "Prodcode", with: @product.prodcode
    fill_in "Tg", with: @product.tg
    fill_in "Varcode", with: @product.varcode
    click_on "Update Product"

    assert_text "Product was successfully updated"
    click_on "Back"
  end

  test "should destroy Product" do
    visit product_url(@product)
    click_on "Destroy this product", match: :first

    assert_text "Product was successfully destroyed"
  end
end
