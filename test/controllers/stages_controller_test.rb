require "test_helper"

class StagesControllerTest < ActionDispatch::IntegrationTest
  test "should get dashboard" do
    get stages_dashboard_url
    assert_response :success
  end

  test "should get sections" do
    get stages_sections_url
    assert_response :success
  end
end
