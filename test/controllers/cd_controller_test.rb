require "test_helper"

class CdControllerTest < ActionDispatch::IntegrationTest
  test "should get ghisetti" do
    get "/cd/ghisetti"
    assert_response :success
  end
end