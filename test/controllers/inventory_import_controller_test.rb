require "test_helper"

class InventoryImportControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

  test "import renders the page" do
    get inventories_import_url
    assert_response :success
  end

  test "import_parse redirects without a file" do
    post inventories_import_parse_url, params: { operationtype_id: 1 }
    assert_redirected_to inventories_import_path
  end

  test "import_parse redirects without an operationtype" do
    post inventories_import_parse_url, params: {}
    assert_redirected_to inventories_import_path
  end

  test "import_verify redirects when no data is cached" do
    Rails.cache.delete("import:inv:")
    get inventories_import_verify_url
    assert_redirected_to inventories_import_path
  end

  test "import_confirm redirects when no data is cached" do
    post inventories_import_confirm_url
    assert_redirected_to inventories_import_path
  end

  test "import_summary redirects to inventories when no stats cached" do
    get inventories_import_summary_url
    assert_redirected_to inventories_path
  end

  test "import_update_row returns 404 when no data is cached" do
    put "/inventories/import/update_row", params: { row_index: 2, field: "Item Code:", value: "NEW" }
    assert_response :not_found
  end

  test "import_cancel clears the cache and redirects" do
    delete inventories_import_cancel_url
    assert_redirected_to inventories_import_path
  end

  test "import_failed_rows redirects when no stats cached" do
    get inventories_import_failed_rows_url
    assert_redirected_to inventories_path
  end
end