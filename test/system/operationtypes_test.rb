require "application_system_test_case"

class OperationtypesTest < ApplicationSystemTestCase
  setup do
    @operationtype = operationtypes(:one)
  end

  test "visiting the index" do
    visit operationtypes_url
    assert_selector "h1", text: "Operationtypes"
  end

  test "should create operationtype" do
    visit operationtypes_url
    click_on "New operationtype"

    fill_in "Code", with: @operationtype.code
    fill_in "Description", with: @operationtype.description
    click_on "Create Operationtype"

    assert_text "Operationtype was successfully created"
    click_on "Back"
  end

  test "should update Operationtype" do
    visit operationtype_url(@operationtype)
    click_on "Edit this operationtype", match: :first

    fill_in "Code", with: @operationtype.code
    fill_in "Description", with: @operationtype.description
    click_on "Update Operationtype"

    assert_text "Operationtype was successfully updated"
    click_on "Back"
  end

  test "should destroy Operationtype" do
    visit operationtype_url(@operationtype)
    click_on "Destroy this operationtype", match: :first

    assert_text "Operationtype was successfully destroyed"
  end
end
