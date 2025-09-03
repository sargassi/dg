require "test_helper"

class ProductionControllerTest < ActionDispatch::IntegrationTest
  test "should get research" do
    get production_research_url
    assert_response :success
  end
end
