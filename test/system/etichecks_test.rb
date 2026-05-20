require "application_system_test_case"

class EtichecksTest < ApplicationSystemTestCase
  setup do
    @eticheck = etichecks(:one)
  end

  test "visiting the index" do
    visit etichecks_url
    assert_selector "h1", text: "Etichecks"
  end

  test "should create eticheck" do
    visit etichecks_url
    click_on "New eticheck"

    fill_in "Chi", with: @eticheck.chi
    fill_in "Cspediti", with: @eticheck.cspediti
    fill_in "Description", with: @eticheck.description
    fill_in "Dove", with: @eticheck.dove
    fill_in "Fabric", with: @eticheck.fabric
    fill_in "Fabricode", with: @eticheck.fabricode
    fill_in "Group", with: @eticheck.group
    fill_in "Itemcode", with: @eticheck.itemcode
    fill_in "Materiale", with: @eticheck.materiale
    fill_in "Qt", with: @eticheck.qt
    fill_in "Tg", with: @eticheck.tg
    fill_in "Varcode", with: @eticheck.varcode
    click_on "Create Eticheck"

    assert_text "Eticheck was successfully created"
    click_on "Back"
  end

  test "should update Eticheck" do
    visit eticheck_url(@eticheck)
    click_on "Edit this eticheck", match: :first

    fill_in "Chi", with: @eticheck.chi
    fill_in "Cspediti", with: @eticheck.cspediti
    fill_in "Description", with: @eticheck.description
    fill_in "Dove", with: @eticheck.dove
    fill_in "Fabric", with: @eticheck.fabric
    fill_in "Fabricode", with: @eticheck.fabricode
    fill_in "Group", with: @eticheck.group
    fill_in "Itemcode", with: @eticheck.itemcode
    fill_in "Materiale", with: @eticheck.materiale
    fill_in "Qt", with: @eticheck.qt
    fill_in "Tg", with: @eticheck.tg
    fill_in "Varcode", with: @eticheck.varcode
    click_on "Update Eticheck"

    assert_text "Eticheck was successfully updated"
    click_on "Back"
  end

  test "should destroy Eticheck" do
    visit eticheck_url(@eticheck)
    click_on "Destroy this eticheck", match: :first

    assert_text "Eticheck was successfully destroyed"
  end
end
