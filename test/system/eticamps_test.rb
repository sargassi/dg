require "application_system_test_case"

class EticampsTest < ApplicationSystemTestCase
  setup do
    @eticamp = eticamps(:one)
  end

  test "visiting the index" do
    visit eticamps_url
    assert_selector "h1", text: "Eticamps"
  end

  test "should create eticamp" do
    visit eticamps_url
    click_on "New eticamp"

    fill_in "Fabricode", with: @eticamp.fabricode
    fill_in "Group", with: @eticamp.group
    fill_in "Itemcode", with: @eticamp.itemcode
    fill_in "Season", with: @eticamp.season
    fill_in "Varcode", with: @eticamp.varcode
    click_on "Create Eticamp"

    assert_text "Eticamp was successfully created"
    click_on "Back"
  end

  test "should update Eticamp" do
    visit eticamp_url(@eticamp)
    click_on "Edit this eticamp", match: :first

    fill_in "Fabricode", with: @eticamp.fabricode
    fill_in "Group", with: @eticamp.group
    fill_in "Itemcode", with: @eticamp.itemcode
    fill_in "Season", with: @eticamp.season
    fill_in "Varcode", with: @eticamp.varcode
    click_on "Update Eticamp"

    assert_text "Eticamp was successfully updated"
    click_on "Back"
  end

  test "should destroy Eticamp" do
    visit eticamp_url(@eticamp)
    click_on "Destroy this eticamp", match: :first

    assert_text "Eticamp was successfully destroyed"
  end
end
