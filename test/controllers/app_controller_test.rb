require "test_helper"

class AppControllerTest < ActionDispatch::IntegrationTest
  test "should get dashboard" do
    get app_dashboard_url
    assert_response :success
  end

  test "should get sez" do
    get app_sez_url
    assert_response :success
  end
end
