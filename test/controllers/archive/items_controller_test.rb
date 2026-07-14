require "test_helper"

class Archive::ItemsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    @item = items(:one)
    Archive::Item.delete_all
  end

  test "import_itemout stores selection in session and redirects" do
    selected = [
      { item_id: @item.id, gencode: @item.gencode, collection_id: @item.collection_id, qty: 2 },
      { item_id: items(:two).id, gencode: items(:two).gencode, collection_id: items(:two).collection_id, qty: 1 }
    ]

    post import_itemout_archive_items_path, params: { selected: selected }

    assert_redirected_to new_itemout_path
    assert_equal 2, session[:archive_itemout_prefill].size
    assert_equal @item.id.to_s, session[:archive_itemout_prefill].first["item_id"]
    assert_equal 2, session[:archive_itemout_prefill].first["qty"].to_i
    assert_equal "2 articoli pronti per lo scarico.", flash[:notice]
  end

  test "import_itemout with empty selection redirects with alert" do
    post import_itemout_archive_items_path, params: { selected: [] }

    assert_redirected_to import_archive_items_path
    assert_equal "Nessun articolo selezionato", flash[:alert]
  end

  test "import_confirm creates Archive::Item records from warehouse items" do
    selected = [
      { item_id: @item.id },
      { item_id: items(:two).id }
    ]

    assert_difference("Archive::Item.count", 2) do
      post import_confirm_archive_items_path, params: { selected: selected }
    end

    assert_redirected_to archive_items_path
    assert_match(/2 articoli importati in archivio/, flash[:notice])

    archive_items = Archive::Item.order(:id).to_a
    assert_equal @item.description, archive_items.first.description
    assert_equal @item.note, archive_items.first.notes
    assert_equal "in", archive_items.first.status
    assert_equal items(:two).description, archive_items.second.description
  end

  test "import_confirm with inventory_id sets it" do
    inventory = inventories(:one)
    selected = [
      { item_id: @item.id, inventory_id: inventory.id }
    ]

    post import_confirm_archive_items_path, params: { selected: selected }

    archive_item = Archive::Item.last
    assert_equal inventory.id, archive_item.inventory_id
  end

  test "import_confirm copies pictures from warehouse items" do
    @item.pictures.attach(
      io: StringIO.new("fake-image-data"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    selected = [{ item_id: @item.id }]

    assert_difference("Archive::Item.count", 1) do
      post import_confirm_archive_items_path, params: { selected: selected }
    end

    archive_item = Archive::Item.last
    assert archive_item.pictures.attached?
    assert_equal @item.pictures.first.blob_id, archive_item.pictures.first.blob_id
  end

  test "import_confirm with empty selection redirects with alert" do
    post import_confirm_archive_items_path, params: { selected: [] }

    assert_redirected_to import_archive_items_path
    assert_equal "Nessun articolo selezionato", flash[:alert]
  end

  test "import_confirm skips non-existent items and reports errors" do
    selected = [
      { item_id: @item.id },
      { item_id: 999999 }
    ]

    post import_confirm_archive_items_path, params: { selected: selected }

    assert_redirected_to archive_items_path
    assert_match(/1 articoli importati in archivio/, flash[:notice])
  end

  test "warehouse_search returns JSON results" do
    get warehouse_search_archive_items_path, params: { q: "TEST" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert json.all? { |r| r.key?("id") }
    assert json.all? { |r| r.key?("gencode") }
    assert json.all? { |r| r.key?("description") }
    assert json.all? { |r| r.key?("qty_remaining") }
  end

  test "warehouse_search with no results returns empty array" do
    get warehouse_search_archive_items_path, params: { q: "zzz_no_match" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_empty json
  end
end
