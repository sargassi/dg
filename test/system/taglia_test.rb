require "application_system_test_case"

class TagliaTest < ApplicationSystemTestCase
  setup do
    @taglium = taglia(:one)
  end

  test "visiting the index" do
    visit taglia_url
    assert_selector "h1", text: "Taglia"
  end

  test "should create taglium" do
    visit taglia_url
    click_on "New taglium"

    fill_in "Description", with: @taglium.description
    click_on "Create Taglium"

    assert_text "Taglium was successfully created"
    click_on "Back"
  end

  test "should update Taglium" do
    visit taglium_url(@taglium)
    click_on "Edit this taglium", match: :first

    fill_in "Description", with: @taglium.description
    click_on "Update Taglium"

    assert_text "Taglium was successfully updated"
    click_on "Back"
  end

  test "should destroy Taglium" do
    visit taglium_url(@taglium)
    click_on "Destroy this taglium", match: :first

    assert_text "Taglium was successfully destroyed"
  end
end
