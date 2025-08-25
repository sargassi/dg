require "test_helper"

class TempestaControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tempestum = tempesta(:one)
  end

  test "should get index" do
    get tempesta_url
    assert_response :success
  end

  test "should get new" do
    get new_tempestum_url
    assert_response :success
  end

  test "should create tempestum" do
    assert_difference("Tempestum.count") do
      post tempesta_url, params: { tempestum: { f0: @tempestum.f0, f1: @tempestum.f1, f1date: @tempestum.f1date, f2: @tempestum.f2, f2date: @tempestum.f2date, f3: @tempestum.f3, f3date: @tempestum.f3date, f4: @tempestum.f4, f4date: @tempestum.f4date, f5: @tempestum.f5, f5date: @tempestum.f5date, prow_id: @tempestum.prow_id } }
    end

    assert_redirected_to tempestum_url(Tempestum.last)
  end

  test "should show tempestum" do
    get tempestum_url(@tempestum)
    assert_response :success
  end

  test "should get edit" do
    get edit_tempestum_url(@tempestum)
    assert_response :success
  end

  test "should update tempestum" do
    patch tempestum_url(@tempestum), params: { tempestum: { f0: @tempestum.f0, f1: @tempestum.f1, f1date: @tempestum.f1date, f2: @tempestum.f2, f2date: @tempestum.f2date, f3: @tempestum.f3, f3date: @tempestum.f3date, f4: @tempestum.f4, f4date: @tempestum.f4date, f5: @tempestum.f5, f5date: @tempestum.f5date, prow_id: @tempestum.prow_id } }
    assert_redirected_to tempestum_url(@tempestum)
  end

  test "should destroy tempestum" do
    assert_difference("Tempestum.count", -1) do
      delete tempestum_url(@tempestum)
    end

    assert_redirected_to tempesta_url
  end
end
