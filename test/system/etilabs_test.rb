require "application_system_test_case"

class EtilabsTest < ApplicationSystemTestCase
  setup do
    @etilab = etilabs(:one)
  end

  test "visiting the index" do
    visit etilabs_url
    assert_selector "h1", text: "Etilabs"
  end

  test "should create etilab" do
    visit etilabs_url
    click_on "New etilab"

    fill_in "Color", with: @etilab.color
    fill_in "Customer", with: @etilab.customer
    fill_in "Description", with: @etilab.description
    fill_in "Fabricode", with: @etilab.fabricode
    fill_in "Group", with: @etilab.group
    fill_in "Itemcode", with: @etilab.itemcode
    fill_in "Materiale", with: @etilab.materiale
    fill_in "Qty", with: @etilab.qty
    fill_in "Supplier", with: @etilab.supplier
    fill_in "Tg", with: @etilab.tg
    fill_in "Varcode", with: @etilab.varcode
    click_on "Create Etilab"

    assert_text "Etilab was successfully created"
    click_on "Back"
  end

  test "should update Etilab" do
    visit etilab_url(@etilab)
    click_on "Edit this etilab", match: :first

    fill_in "Color", with: @etilab.color
    fill_in "Customer", with: @etilab.customer
    fill_in "Description", with: @etilab.description
    fill_in "Fabricode", with: @etilab.fabricode
    fill_in "Group", with: @etilab.group
    fill_in "Itemcode", with: @etilab.itemcode
    fill_in "Materiale", with: @etilab.materiale
    fill_in "Qty", with: @etilab.qty
    fill_in "Supplier", with: @etilab.supplier
    fill_in "Tg", with: @etilab.tg
    fill_in "Varcode", with: @etilab.varcode
    click_on "Update Etilab"

    assert_text "Etilab was successfully updated"
    click_on "Back"
  end

  test "should destroy Etilab" do
    visit etilab_url(@etilab)
    click_on "Destroy this etilab", match: :first

    assert_text "Etilab was successfully destroyed"
  end
end
