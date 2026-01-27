require "application_system_test_case"

class FabriclusTest < ApplicationSystemTestCase
  setup do
    @fabriclu = fabriclus(:one)
  end

  test "visiting the index" do
    visit fabriclus_url
    assert_selector "h1", text: "Fabriclus"
  end

  test "should create fabriclu" do
    visit fabriclus_url
    click_on "New fabriclu"

    fill_in "Color", with: @fabriclu.color
    fill_in "Customer", with: @fabriclu.customer
    fill_in "Description", with: @fabriclu.description
    fill_in "Fab", with: @fabriclu.fab
    fill_in "Materiale", with: @fabriclu.materiale
    fill_in "Note", with: @fabriclu.note
    fill_in "Qty", with: @fabriclu.qty
    fill_in "Supplier", with: @fabriclu.supplier
    fill_in "Tg", with: @fabriclu.tg
    fill_in "Var", with: @fabriclu.var
    fill_in "Year", with: @fabriclu.year
    click_on "Create Fabriclu"

    assert_text "Fabriclu was successfully created"
    click_on "Back"
  end

  test "should update Fabriclu" do
    visit fabriclu_url(@fabriclu)
    click_on "Edit this fabriclu", match: :first

    fill_in "Color", with: @fabriclu.color
    fill_in "Customer", with: @fabriclu.customer
    fill_in "Description", with: @fabriclu.description
    fill_in "Fab", with: @fabriclu.fab
    fill_in "Materiale", with: @fabriclu.materiale
    fill_in "Note", with: @fabriclu.note
    fill_in "Qty", with: @fabriclu.qty
    fill_in "Supplier", with: @fabriclu.supplier
    fill_in "Tg", with: @fabriclu.tg
    fill_in "Var", with: @fabriclu.var
    fill_in "Year", with: @fabriclu.year
    click_on "Update Fabriclu"

    assert_text "Fabriclu was successfully updated"
    click_on "Back"
  end

  test "should destroy Fabriclu" do
    visit fabriclu_url(@fabriclu)
    click_on "Destroy this fabriclu", match: :first

    assert_text "Fabriclu was successfully destroyed"
  end
end
