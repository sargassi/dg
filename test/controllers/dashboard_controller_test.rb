require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "should get home" do
    sign_in users(:one)
    get dashboard_home_url
    assert_response :success
  end

  test "godlike sees portal on root" do
    sign_in users(:one)
    get root_url
    assert_response :success
    assert_select "h2", text: "Articoli"
    assert_select "h2", text: "Magazzino"
    assert_select "h2", text: "Produzione"
    assert_select "a[href=?]", admin_users_path
  end

  test "non godlike does not see portal on root" do
    sign_in users(:two)
    get root_url
    assert_response :success
    assert_select "h2", text: "Articoli", count: 0
  end
end
