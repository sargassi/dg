require "test_helper"

class InventoryImportController
  private

  def import_cache_key
    "import:inv:test"
  end

  def import_status_key
    "import:inv:status:test"
  end
end

class InventoryImportControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    sign_in users(:one)
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    ActiveJob::Base.queue_adapter = :test
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

  test "import_parse redirects to processing and parses in the background" do
    package = Axlsx::Package.new
    package.workbook.add_worksheet do |sheet|
      sheet.add_row ["dove", "Item Code:", "Description: ", "Qt."]
      sheet.add_row ["WH", "TEST001", "Desc", "2"]
      sheet.add_row ["WH", "NEWY", "Desc", "1"]
    end
    file = Tempfile.new(["import", ".xlsx"])
    file.write(package.to_stream.read)
    file.rewind
    upload = Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    post inventories_import_parse_url, params: { file: upload, operationtype_id: 1 }

    assert_redirected_to inventories_import_processing_path
    assert_equal "processing", Rails.cache.read("import:inv:status:test")[:state]

    perform_enqueued_jobs

    data = Rails.cache.read("import:inv:test")
    assert_equal 2, data[:rows].size
    assert_equal "done", Rails.cache.read("import:inv:status:test")[:state]
    assert_equal 2, Rails.cache.read("import:inv:status:test")[:rows]
    assert_empty Dir.glob(Rails.root.join("tmp", "imports", "inv_*.xlsx"))
  ensure
    file&.close
    file&.unlink
  end

  test "import_create_missing_items creates items from a parsed file and redirects" do
    package = Axlsx::Package.new
    package.workbook.add_worksheet do |sheet|
      sheet.add_row ["dove", "Item Code:", "Fabric code:", "var. code:", "Description: ", "Tg.", "Note:", "Qt."]
      sheet.add_row ["WH", "NEWX", "F1", "V1", "Desc test", "unique", "Coll Nuova", "2"]
    end
    file = Tempfile.new(["import", ".xlsx"])
    file.write(package.to_stream.read)
    file.rewind
    upload = Rack::Test::UploadedFile.new(file.path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

    post inventories_import_parse_url, params: { file: upload, operationtype_id: 1 }
    perform_enqueued_jobs

    assert_difference("Item.count", 1) do
      post inventories_import_create_missing_items_url
    end

    assert_redirected_to inventories_import_path
    item = Item.find_by(itemcode: "NEWX")
    assert_not_nil item
    assert_equal "F1", item.fabricode
    assert_equal "Coll Nuova", item.collection.description
  ensure
    file&.close
    file&.unlink
  end

  test "import_create_missing_items redirects when no data is cached" do
    post inventories_import_create_missing_items_url
    assert_redirected_to inventories_import_path
  end

  test "import_processing redirects home when no parse is running" do
    get inventories_import_processing_url
    assert_redirected_to inventories_import_path
  end

  test "import_processing renders the progress page while parsing" do
    Rails.cache.write("import:inv:status:test", { state: "processing" })
    get inventories_import_processing_url
    assert_response :success
    assert_match(/Elaborazione file in corso/, response.body)
  end

  test "import_processing redirects to preview when the parse is done" do
    Rails.cache.write("import:inv:status:test", { state: "done", rows: 3 })
    get inventories_import_processing_url
    assert_redirected_to inventories_import_path
  end

  test "import_status_json reports progress while processing and done at completion" do
    Rails.cache.write("import:inv:status:test", { state: "processing" })
    get inventories_import_status_url
    assert_equal({ "total" => 1, "done" => 0, "complete" => false }, JSON.parse(response.body))

    Rails.cache.write("import:inv:status:test", { state: "done", rows: 10 })
    get inventories_import_status_url
    assert_equal({ "total" => 10, "done" => 10, "complete" => true }, JSON.parse(response.body))

    Rails.cache.write("import:inv:status:test", { state: "error", error: "boom" })
    get inventories_import_status_url
    body = JSON.parse(response.body)
    assert_equal true, body["complete"]
    assert_equal "boom", body["error"]
  end

  test "import_verify redirects when no data is cached" do
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

  test "import renders the preview with invalid rows, error panel and create button" do
    data = {
      operationtype_id: 1,
      headers: ["dove", "Item Code:", "Description: ", "Qt."],
      rows: [
        {
          _index: 1, _valid: false, _error: "Articolo X non trovato",
          "Item Code:" => "X", "Qt." => 1,
          _warehouse_id: 1, _warehouse_code: "WH1", _warehouse_new: false,
          _location_id: nil, _collection_id: nil
        },
        {
          _index: 2, _valid: true,
          "Item Code:" => "TEST001", "Qt." => 2,
          _warehouse_id: 1, _warehouse_code: "WH1", _warehouse_new: false,
          _collection_id: 1, _collection_description: "Coll", _collection_new: false
        }
      ]
    }
    Rails.cache.write("import:inv:test", data)

    get inventories_import_url

    assert_response :success
    assert_match(/1 riga non valid/, response.body)
    assert_match(/Articolo X non trovato/, response.body)
    assert_match(/Codici articolo mancanti/, response.body)
    assert_match(/Crea 1 articoli mancanti/, response.body)
  end
end