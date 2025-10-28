require "test_helper"

class CdControllerTest < ActionDispatch::IntegrationTest
  test "should get ../ghisetti" do
    get cd_../ghisetti_url
    assert_response :success
  end
end
