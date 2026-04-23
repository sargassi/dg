require "application_system_test_case"

class IteminsTest < ApplicationSystemTestCase
  setup do
    @itemin = itemins(:one)
  end

  test "visiting the index" do
    visit itemins_url
    assert_selector "h1", text: "Itemins"
  end

  test "should create itemin" do
    visit itemins_url
    click_on "New itemin"

    fill_in "Indate", with: @itemin.indate
    fill_in "Operator", with: @itemin.operator_id
    click_on "Create Itemin"

    assert_text "Itemin was successfully created"
    click_on "Back"
  end

  test "should update Itemin" do
    visit itemin_url(@itemin)
    click_on "Edit this itemin", match: :first

    fill_in "Indate", with: @itemin.indate
    fill_in "Operator", with: @itemin.operator_id
    click_on "Update Itemin"

    assert_text "Itemin was successfully updated"
    click_on "Back"
  end

  test "should destroy Itemin" do
    visit itemin_url(@itemin)
    click_on "Destroy this itemin", match: :first

    assert_text "Itemin was successfully destroyed"
  end
end
