require "application_system_test_case"

class ItemoutsTest < ApplicationSystemTestCase
  setup do
    @itemout = itemouts(:one)
  end

  test "visiting the index" do
    visit itemouts_url
    assert_selector "h1", text: "Itemouts"
  end

  test "should create itemout" do
    visit itemouts_url
    click_on "New itemout"

    fill_in "Indate", with: @itemout.indate
    click_on "Create Itemout"

    assert_text "Itemout was successfully created"
    click_on "Back"
  end

  test "should update Itemout" do
    visit itemout_url(@itemout)
    click_on "Edit this itemout", match: :first

    fill_in "Indate", with: @itemout.indate
    click_on "Update Itemout"

    assert_text "Itemout was successfully updated"
    click_on "Back"
  end

  test "should destroy Itemout" do
    visit itemout_url(@itemout)
    click_on "Destroy this itemout", match: :first

    assert_text "Itemout was successfully destroyed"
  end
end
