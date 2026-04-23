require "test_helper"

class ItemoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @itemout = itemouts(:one)
  end

  test "should get index" do
    get itemouts_url
    assert_response :success
  end

  test "should get new" do
    get new_itemout_url
    assert_response :success
  end

  test "should create itemout" do
    assert_difference("Itemout.count") do
      post itemouts_url, params: { itemout: { indate: @itemout.indate, operator_id: @itemout.operator_id } }
    end

    assert_redirected_to itemout_url(Itemout.last)
  end

  test "should show itemout" do
    get itemout_url(@itemout)
    assert_response :success
  end

  test "should get edit" do
    get edit_itemout_url(@itemout)
    assert_response :success
  end

  test "should update itemout" do
    patch itemout_url(@itemout), params: { itemout: { indate: @itemout.indate, operator_id: @itemout.operator_id } }
    assert_redirected_to itemout_url(@itemout)
  end

  test "should destroy itemout" do
    assert_difference("Itemout.count", -1) do
      delete itemout_url(@itemout)
    end

    assert_redirected_to itemouts_url
  end
end
