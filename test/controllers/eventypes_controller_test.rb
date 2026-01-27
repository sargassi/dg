require "test_helper"

class EventypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @eventype = eventypes(:one)
  end

  test "should get index" do
    get eventypes_url
    assert_response :success
  end

  test "should get new" do
    get new_eventype_url
    assert_response :success
  end

  test "should create eventype" do
    assert_difference("Eventype.count") do
      post eventypes_url, params: { eventype: { enabled: @eventype.enabled, name: @eventype.name } }
    end

    assert_redirected_to eventype_url(Eventype.last)
  end

  test "should show eventype" do
    get eventype_url(@eventype)
    assert_response :success
  end

  test "should get edit" do
    get edit_eventype_url(@eventype)
    assert_response :success
  end

  test "should update eventype" do
    patch eventype_url(@eventype), params: { eventype: { enabled: @eventype.enabled, name: @eventype.name } }
    assert_redirected_to eventype_url(@eventype)
  end

  test "should destroy eventype" do
    assert_difference("Eventype.count", -1) do
      delete eventype_url(@eventype)
    end

    assert_redirected_to eventypes_url
  end
end
