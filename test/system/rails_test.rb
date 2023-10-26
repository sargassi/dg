require "application_system_test_case"

class RailsTest < ApplicationSystemTestCase
  setup do
    @rail = rails(:one)
  end

  test "visiting the index" do
    visit rails_url
    assert_selector "h1", text: "Rails"
  end

  test "should create rail" do
    visit rails_url
    click_on "New rail"

    fill_in "Area", with: @rail.area_id
    fill_in "G", with: @rail.g
    fill_in "Migration", with: @rail.migration
    fill_in "Prodcode", with: @rail.prodcode_id
    fill_in "Prodrow", with: @rail.prodrow
    fill_in "Pub", with: @rail.pub
    fill_in "User", with: @rail.user
    click_on "Create Rail"

    assert_text "Rail was successfully created"
    click_on "Back"
  end

  test "should update Rail" do
    visit rail_url(@rail)
    click_on "Edit this rail", match: :first

    fill_in "Area", with: @rail.area_id
    fill_in "G", with: @rail.g
    fill_in "Migration", with: @rail.migration
    fill_in "Prodcode", with: @rail.prodcode_id
    fill_in "Prodrow", with: @rail.prodrow
    fill_in "Pub", with: @rail.pub
    fill_in "User", with: @rail.user
    click_on "Update Rail"

    assert_text "Rail was successfully updated"
    click_on "Back"
  end

  test "should destroy Rail" do
    visit rail_url(@rail)
    click_on "Destroy this rail", match: :first

    assert_text "Rail was successfully destroyed"
  end
end
