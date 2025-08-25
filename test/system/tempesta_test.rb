require "application_system_test_case"

class TempestaTest < ApplicationSystemTestCase
  setup do
    @tempestum = tempesta(:one)
  end

  test "visiting the index" do
    visit tempesta_url
    assert_selector "h1", text: "Tempesta"
  end

  test "should create tempestum" do
    visit tempesta_url
    click_on "New tempestum"

    check "F0" if @tempestum.f0
    check "F1" if @tempestum.f1
    fill_in "F1date", with: @tempestum.f1date
    check "F2" if @tempestum.f2
    fill_in "F2date", with: @tempestum.f2date
    check "F3" if @tempestum.f3
    fill_in "F3date", with: @tempestum.f3date
    check "F4" if @tempestum.f4
    fill_in "F4date", with: @tempestum.f4date
    check "F5" if @tempestum.f5
    fill_in "F5date", with: @tempestum.f5date
    fill_in "Prow", with: @tempestum.prow_id
    click_on "Create Tempestum"

    assert_text "Tempestum was successfully created"
    click_on "Back"
  end

  test "should update Tempestum" do
    visit tempestum_url(@tempestum)
    click_on "Edit this tempestum", match: :first

    check "F0" if @tempestum.f0
    check "F1" if @tempestum.f1
    fill_in "F1date", with: @tempestum.f1date
    check "F2" if @tempestum.f2
    fill_in "F2date", with: @tempestum.f2date
    check "F3" if @tempestum.f3
    fill_in "F3date", with: @tempestum.f3date
    check "F4" if @tempestum.f4
    fill_in "F4date", with: @tempestum.f4date
    check "F5" if @tempestum.f5
    fill_in "F5date", with: @tempestum.f5date
    fill_in "Prow", with: @tempestum.prow_id
    click_on "Update Tempestum"

    assert_text "Tempestum was successfully updated"
    click_on "Back"
  end

  test "should destroy Tempestum" do
    visit tempestum_url(@tempestum)
    click_on "Destroy this tempestum", match: :first

    assert_text "Tempestum was successfully destroyed"
  end
end
