require "test_helper"

class IteminsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @itemin = itemins(:one)
  end

  test "should get index" do
    get itemins_url
    assert_response :success
  end

  test "should get new" do
    get new_itemin_url
    assert_response :success
  end

  test "should create itemin" do
    assert_difference("Itemin.count") do
      post itemins_url, params: { itemin: { indate: @itemin.indate, operator_id: @itemin.operator_id } }
    end

    assert_redirected_to itemin_url(Itemin.last)
  end

  test "should show itemin" do
    get itemin_url(@itemin)
    assert_response :success
  end

  test "should get edit" do
    get edit_itemin_url(@itemin)
    assert_response :success
  end

  test "should update itemin" do
    patch itemin_url(@itemin), params: { itemin: { indate: @itemin.indate, operator_id: @itemin.operator_id } }
    assert_redirected_to itemin_url(@itemin)
  end

  test "should destroy itemin" do
    assert_difference("Itemin.count", -1) do
      delete itemin_url(@itemin)
    end

    assert_redirected_to itemins_url
  end
end
