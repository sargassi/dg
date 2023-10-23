require "test_helper"

class UtilitiesControllerTest < ActionDispatch::IntegrationTest
  test "should get etichette" do
    get utilities_etichette_url
    assert_response :success
  end
end
