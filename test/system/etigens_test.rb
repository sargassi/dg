require "application_system_test_case"

class EtigensTest < ApplicationSystemTestCase
  setup do
    @etigen = etigens(:one)
  end

  test "visiting the index" do
    visit etigens_url
    assert_selector "h1", text: "Etigens"
  end

  test "should create etigen" do
    visit etigens_url
    click_on "New etigen"

    fill_in "Group", with: @etigen.group
    fill_in "Qty", with: @etigen.qty
    fill_in "Riga1", with: @etigen.riga1
    fill_in "Riga2", with: @etigen.riga2
    fill_in "Riga3", with: @etigen.riga3
    fill_in "Riga4", with: @etigen.riga4
    fill_in "Riga5", with: @etigen.riga5
    check "Status" if @etigen.status
    click_on "Create Etigen"

    assert_text "Etigen was successfully created"
    click_on "Back"
  end

  test "should update Etigen" do
    visit etigen_url(@etigen)
    click_on "Edit this etigen", match: :first

    fill_in "Group", with: @etigen.group
    fill_in "Qty", with: @etigen.qty
    fill_in "Riga1", with: @etigen.riga1
    fill_in "Riga2", with: @etigen.riga2
    fill_in "Riga3", with: @etigen.riga3
    fill_in "Riga4", with: @etigen.riga4
    fill_in "Riga5", with: @etigen.riga5
    check "Status" if @etigen.status
    click_on "Update Etigen"

    assert_text "Etigen was successfully updated"
    click_on "Back"
  end

  test "should destroy Etigen" do
    visit etigen_url(@etigen)
    click_on "Destroy this etigen", match: :first

    assert_text "Etigen was successfully destroyed"
  end
end
