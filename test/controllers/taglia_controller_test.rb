require "test_helper"

class TagliaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @taglium = taglia(:one)
  end

  test "should get index" do
    get taglia_url
    assert_response :success
  end

  test "should get new" do
    get new_taglium_url
    assert_response :success
  end

  test "should create taglium" do
    assert_difference("Taglium.count") do
      post taglia_url, params: { taglium: { description: @taglium.description } }
    end

    assert_redirected_to taglium_url(Taglium.last)
  end

  test "should show taglium" do
    get taglium_url(@taglium)
    assert_response :success
  end

  test "should get edit" do
    get edit_taglium_url(@taglium)
    assert_response :success
  end

  test "should update taglium" do
    patch taglium_url(@taglium), params: { taglium: { description: @taglium.description } }
    assert_redirected_to taglium_url(@taglium)
  end

  test "should destroy taglium" do
    assert_difference("Taglium.count", -1) do
      delete taglium_url(@taglium)
    end

    assert_redirected_to taglia_url
  end
end
