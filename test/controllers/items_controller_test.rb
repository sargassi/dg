require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
    @item = items(:one)
  end

  test "should get index" do
    get items_url
    assert_response :success
  end

  test "should get new" do
    get new_item_url
    assert_response :success
  end

  test "should create item" do
    assert_difference("Item.count") do
      post items_url, params: { item: { colour: @item.colour, description: @item.description, fabric: @item.fabric, fabricode: @item.fabricode, itemcode: @item.itemcode, materiale: @item.materiale, note: @item.note, tg: @item.tg, unit_price: @item.unit_price, varcode: @item.varcode, collection_id: collections(:one).id } }
    end

    assert_redirected_to create_confirmation_items_path(item_id: Item.last.id)
  end

  test "should show item" do
    get item_url(@item)
    assert_response :success
  end

  test "should get edit" do
    get edit_item_url(@item)
    assert_response :success
  end

  test "should update item" do
    patch item_url(@item), params: { item: { colour: @item.colour, description: @item.description, fabric: @item.fabric, fabricode: @item.fabricode, itemcode: @item.itemcode, materiale: @item.materiale, note: @item.note, tg: @item.tg, unit_price: @item.unit_price, varcode: @item.varcode, collection_id: @item.collection_id } }
    assert_redirected_to mainware_index_path
  end

  test "should destroy item" do
    assert_difference("Item.count", -1) do
      delete item_url(@item)
    end

    assert_redirected_to mainware_index_path
  end

  test "should get combination drawer content" do
    get combination_items_url, headers: { "Turbo-Frame" => "combination_drawer_content" }
    assert_response :success
    assert_match "combination_drawer_content", response.body
    assert_select "input[name='item[itemcode]']"
    assert_select "input[name='item[fabricode]']"
    assert_select "input[name='item[varcode]']"
  end

  test "combination_info returns composed code and gencode" do
    get combination_info_items_url, params: { itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection_id: collections(:one).id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ABC123FAB99901", body["composed"]
    assert_equal "ABC123FAB99901_#{collections(:one).id}", body["gencode"]
    assert_equal false, body["exact_exists"]
    assert_equal [], body["siblings"]
  end

  test "combination_info flags exact existing gencode" do
    created = Item.create!(itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection: collections(:one), description: "x")
    get combination_info_items_url, params: { itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection_id: collections(:one).id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["exact_exists"]
    assert_equal created.gencode, body["gencode"]
  end

  test "combination_info lists siblings from other collections but not the same collection" do
    Item.create!(itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection: collections(:one), description: "In one")
    Item.create!(itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection: collections(:two), description: "In two")

    get combination_info_items_url, params: { itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection_id: collections(:one).id }
    body = JSON.parse(response.body)
    assert_equal ["MyText"], body["siblings"].map { |s| s["collection"] }
    assert_equal collections(:two).id, body["siblings"].first["collection_id"]

    get combination_info_items_url, params: { itemcode: "ABC123", fabricode: "FAB999", varcode: "01" }
    body = JSON.parse(response.body)
    assert_equal 2, body["siblings"].size
    assert_nil body["gencode"]
  end

  test "combination_info excludes the current item via exclude_id" do
    created = Item.create!(itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection: collections(:one), description: "x")
    get combination_info_items_url, params: { itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection_id: collections(:one).id, exclude_id: created.id }
    body = JSON.parse(response.body)
    assert_equal false, body["exact_exists"]
  end

  test "combination_info returns suggestions from existing codes" do
    Item.create!(itemcode: "ABC123", fabricode: "FAB999", varcode: "01", collection: collections(:one), description: "Tessuto blu", tg: "M", fabric: "Cotton", colour: "Blue", materiale: "Cotone")

    get combination_info_items_url, params: { itemcode: "ABC123", fabricode: "FAB999", varcode: "02" }
    body = JSON.parse(response.body)
    assert_equal "Tessuto blu", body["suggestions"]["description"]
    assert_equal "Cotton", body["suggestions"]["fabric"]
    assert_equal "Blue", body["suggestions"]["colour"]
  end

  test "combination_info returns bad request when all codes are blank" do
    get combination_info_items_url, params: { itemcode: "", fabricode: "", varcode: "" }
    assert_response :bad_request
  end

  test "distinct_values filters fabricode by itemcode" do
    Item.create!(itemcode: "AAA", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "a")
    Item.create!(itemcode: "BBB", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "b")
    Item.create!(itemcode: "AAA", fabricode: "F2", varcode: "V1", collection: collections(:one), description: "c")

    get distinct_values_items_url, params: { field: "fabricode", q: "F", itemcode: "AAA" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal ["F1", "F2"], body
  end

  test "distinct_values filters varcode by itemcode and fabricode" do
    Item.create!(itemcode: "AAA", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "a")
    Item.create!(itemcode: "AAA", fabricode: "F1", varcode: "V2", collection: collections(:one), description: "b")
    Item.create!(itemcode: "AAA", fabricode: "F2", varcode: "V3", collection: collections(:one), description: "c")

    get distinct_values_items_url, params: { field: "varcode", q: "V", itemcode: "AAA", fabricode: "F1" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal ["V1", "V2"], body
  end

  test "distinct_values rejects unknown field" do
    get distinct_values_items_url, params: { field: "bogus", q: "x" }
    assert_response :bad_request
  end

  test "distinct_values returns values alphabetically ordered" do
    Item.create!(itemcode: "ZZZ", fabricode: "F2", varcode: "V1", collection: collections(:one), description: "a")
    Item.create!(itemcode: "AAA", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "b")
    Item.create!(itemcode: "MMM", fabricode: "F3", varcode: "V1", collection: collections(:one), description: "c")

    get distinct_values_items_url, params: { field: "itemcode", q: "" }
    body = JSON.parse(response.body)
    sorted = body.sort
    assert_equal sorted, body
    assert_includes body, "AAA"
    assert_includes body, "MMM"
    assert_includes body, "ZZZ"
  end

  test "distinct_values returns all values for empty query and honors limit" do
    Item.create!(itemcode: "AAA", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "a")
    Item.create!(itemcode: "BBB", fabricode: "F2", varcode: "V2", collection: collections(:one), description: "b")
    Item.create!(itemcode: "CCC", fabricode: "F3", varcode: "V3", collection: collections(:one), description: "c")

    get distinct_values_items_url, params: { field: "itemcode", q: "" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body, "AAA"
    assert_includes body, "BBB"

    get distinct_values_items_url, params: { field: "itemcode", q: "", limit: "1" }
    body = JSON.parse(response.body)
    assert_equal 1, body.size
  end

  test "value_info reports fabricode used outside the itemcode" do
    Item.create!(itemcode: "AAA", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "a")
    Item.create!(itemcode: "BBB", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "b")

    get value_info_items_url, params: { field: "fabricode", value: "F1", itemcode: "AAA" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["exists"]
    assert_equal 1, body["count"]
  end

  test "value_info reports fabricode unused outside the itemcode" do
    Item.create!(itemcode: "AAA", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "a")

    get value_info_items_url, params: { field: "fabricode", value: "F1", itemcode: "AAA" }
    body = JSON.parse(response.body)
    assert_equal false, body["exists"]
    assert_equal 0, body["count"]
  end

  test "value_info reports varcode used outside the itemcode+fabricode combination" do
    Item.create!(itemcode: "AAA", fabricode: "F1", varcode: "V1", collection: collections(:one), description: "a")
    Item.create!(itemcode: "AAA", fabricode: "F2", varcode: "V1", collection: collections(:one), description: "b")

    get value_info_items_url, params: { field: "varcode", value: "V1", itemcode: "AAA", fabricode: "F1" }
    body = JSON.parse(response.body)
    assert_equal true, body["exists"]
    assert_equal 1, body["count"]
  end

  test "value_info rejects unknown field or empty value" do
    get value_info_items_url, params: { field: "bogus", value: "x" }
    assert_response :bad_request
    get value_info_items_url, params: { field: "fabricode", value: "" }
    assert_response :bad_request
  end
end
