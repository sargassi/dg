require "test_helper"

class MainwareControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get mainware_index_url
    assert_response :success
  end

  test "should get search" do
    get mainware_search_url
    assert_response :success
  end

  test "should get searchqr" do
    get mainware_searchqr_url
    assert_response :success
  end
end
