require "application_system_test_case"

class ProwsTest < ApplicationSystemTestCase
  setup do
    @prow = prows(:one)
  end

  test "visiting the index" do
    visit prows_url
    assert_selector "h1", text: "Prows"
  end

  test "should create prow" do
    visit prows_url
    click_on "New prow"

    fill_in "Code", with: @prow.code
    fill_in "Description", with: @prow.description
    fill_in "Note", with: @prow.note
    fill_in "Proforma", with: @prow.proforma_id
    fill_in "Qr", with: @prow.qr
    fill_in "Qty", with: @prow.qty
    click_on "Create Prow"

    assert_text "Prow was successfully created"
    click_on "Back"
  end

  test "should update Prow" do
    visit prow_url(@prow)
    click_on "Edit this prow", match: :first

    fill_in "Code", with: @prow.code
    fill_in "Description", with: @prow.description
    fill_in "Note", with: @prow.note
    fill_in "Proforma", with: @prow.proforma_id
    fill_in "Qr", with: @prow.qr
    fill_in "Qty", with: @prow.qty
    click_on "Update Prow"

    assert_text "Prow was successfully updated"
    click_on "Back"
  end

  test "should destroy Prow" do
    visit prow_url(@prow)
    click_on "Destroy this prow", match: :first

    assert_text "Prow was successfully destroyed"
  end
end
