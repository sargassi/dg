require "application_system_test_case"

class ProformasTest < ApplicationSystemTestCase
  setup do
    @proforma = proformas(:one)
  end

  test "visiting the index" do
    visit proformas_url
    assert_selector "h1", text: "Proformas"
  end

  test "should create proforma" do
    visit proformas_url
    click_on "New proforma"

    check "Closed" if @proforma.closed
    fill_in "Customer", with: @proforma.customer
    fill_in "Data in", with: @proforma.data_in
    fill_in "Data out", with: @proforma.data_out
    fill_in "Note", with: @proforma.note
    click_on "Create Proforma"

    assert_text "Proforma was successfully created"
    click_on "Back"
  end

  test "should update Proforma" do
    visit proforma_url(@proforma)
    click_on "Edit this proforma", match: :first

    check "Closed" if @proforma.closed
    fill_in "Customer", with: @proforma.customer
    fill_in "Data in", with: @proforma.data_in
    fill_in "Data out", with: @proforma.data_out
    fill_in "Note", with: @proforma.note
    click_on "Update Proforma"

    assert_text "Proforma was successfully updated"
    click_on "Back"
  end

  test "should destroy Proforma" do
    visit proforma_url(@proforma)
    click_on "Destroy this proforma", match: :first

    assert_text "Proforma was successfully destroyed"
  end
end
