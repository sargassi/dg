require "test_helper"

class EtichecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @eticheck = etichecks(:one)
  end

  test "should get index" do
    get etichecks_url
    assert_response :success
  end

  test "should get new" do
    get new_eticheck_url
    assert_response :success
  end

  test "should create eticheck" do
    assert_difference("Eticheck.count") do
      post etichecks_url, params: { eticheck: { chi: @eticheck.chi, cspediti: @eticheck.cspediti, description: @eticheck.description, dove: @eticheck.dove, fabric: @eticheck.fabric, fabricode: @eticheck.fabricode, group: @eticheck.group, itemcode: @eticheck.itemcode, materiale: @eticheck.materiale, qt: @eticheck.qt, tg: @eticheck.tg, varcode: @eticheck.varcode } }
    end

    assert_redirected_to eticheck_url(Eticheck.last)
  end

  test "should show eticheck" do
    get eticheck_url(@eticheck)
    assert_response :success
  end

  test "should get edit" do
    get edit_eticheck_url(@eticheck)
    assert_response :success
  end

  test "should update eticheck" do
    patch eticheck_url(@eticheck), params: { eticheck: { chi: @eticheck.chi, cspediti: @eticheck.cspediti, description: @eticheck.description, dove: @eticheck.dove, fabric: @eticheck.fabric, fabricode: @eticheck.fabricode, group: @eticheck.group, itemcode: @eticheck.itemcode, materiale: @eticheck.materiale, qt: @eticheck.qt, tg: @eticheck.tg, varcode: @eticheck.varcode } }
    assert_redirected_to eticheck_url(@eticheck)
  end

  test "should destroy eticheck" do
    assert_difference("Eticheck.count", -1) do
      delete eticheck_url(@eticheck)
    end

    assert_redirected_to etichecks_url
  end
end
