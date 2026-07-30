require "test_helper"

class MainwareControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

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

  test "should search by q in searchqr" do
    get mainware_searchqr_url, params: { q: "MyString" }
    assert_response :success
  end

  test "should download import template" do
    get mainware_import_template_url
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match(/template_import_articoli\.xlsx/, response.headers["Content-Disposition"])
  end

  test "should reject non xlsx import files" do
    file = Tempfile.new(["wrong", ".txt"])
    file.write("not an excel")
    file.rewind
    post mainware_import_parse_url, params: { file: Rack::Test::UploadedFile.new(file.path, "text/plain") }
    assert_redirected_to mainware_import_url
    assert_equal "Il file deve essere in formato .xlsx", flash[:alert]
  ensure
    file.close
    file.unlink
  end
end
