require "application_system_test_case"

class EventypesTest < ApplicationSystemTestCase
  setup do
    @eventype = eventypes(:one)
  end

  test "visiting the index" do
    visit eventypes_url
    assert_selector "h1", text: "Eventypes"
  end

  test "should create eventype" do
    visit eventypes_url
    click_on "New eventype"

    check "Enabled" if @eventype.enabled
    fill_in "Name", with: @eventype.name
    click_on "Create Eventype"

    assert_text "Eventype was successfully created"
    click_on "Back"
  end

  test "should update Eventype" do
    visit eventype_url(@eventype)
    click_on "Edit this eventype", match: :first

    check "Enabled" if @eventype.enabled
    fill_in "Name", with: @eventype.name
    click_on "Update Eventype"

    assert_text "Eventype was successfully updated"
    click_on "Back"
  end

  test "should destroy Eventype" do
    visit eventype_url(@eventype)
    click_on "Destroy this eventype", match: :first

    assert_text "Eventype was successfully destroyed"
  end
end
