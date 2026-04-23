require "test_helper"

class EticampsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @eticamp = eticamps(:one)
  end

  test "should get index" do
    get eticamps_url
    assert_response :success
  end

  test "should get new" do
    get new_eticamp_url
    assert_response :success
  end

  test "should create eticamp" do
    assert_difference("Eticamp.count") do
      post eticamps_url, params: { eticamp: { fabricode: @eticamp.fabricode, group: @eticamp.group, itemcode: @eticamp.itemcode, season: @eticamp.season, varcode: @eticamp.varcode } }
    end

    assert_redirected_to eticamp_url(Eticamp.last)
  end

  test "should show eticamp" do
    get eticamp_url(@eticamp)
    assert_response :success
  end

  test "should get edit" do
    get edit_eticamp_url(@eticamp)
    assert_response :success
  end

  test "should update eticamp" do
    patch eticamp_url(@eticamp), params: { eticamp: { fabricode: @eticamp.fabricode, group: @eticamp.group, itemcode: @eticamp.itemcode, season: @eticamp.season, varcode: @eticamp.varcode } }
    assert_redirected_to eticamp_url(@eticamp)
  end

  test "should destroy eticamp" do
    assert_difference("Eticamp.count", -1) do
      delete eticamp_url(@eticamp)
    end

    assert_redirected_to eticamps_url
  end
end
