require "test_helper"

class ImportInventoryServiceTest < ActiveSupport::TestCase
  setup do
    @item = items(:one)
    @warehouse = warehouses(:one)
    @user = users(:one)
    Operationtype.find_or_create_by!(id: 1) do |op|
      op.code = "IN"
      op.description = "Carico"
    end
    Operationtype.find_or_create_by!(id: 2) do |op|
      op.code = "OUT"
      op.description = "Uscita"
    end
  end

  test "save skips a row when the cached item was deleted after parsing" do
    data = {
      operationtype_id: 1,
      warehouse_id: @warehouse.id,
      rows: [
        {
          _index: 1,
          _valid: true,
          _item_id: 999_999,
          "Item Code:" => "NONEXISTENT",
          "Qt." => 5
        }
      ]
    }

    stats = ImportInventoryService.new.save(data, @user)

    assert_equal 0, stats[:created]
    assert_equal 1, stats[:invalid].size
    assert_equal "Articolo non trovato", stats[:invalid].first[:error]
  end

  test "save creates a movement and stores the item's actual itemcode" do
    data = {
      operationtype_id: 1,
      warehouse_id: @warehouse.id,
      rows: [
        {
          _index: 1,
          _valid: true,
          _item_id: @item.id,
          "Item Code:" => @item.gencode,
          "Qt." => 5
        }
      ]
    }

    stats = ImportInventoryService.new.save(data, @user)

    assert_equal 1, stats[:created]
    inventory = Inventory.find_by(item_id: @item.id)
    assert_not_nil inventory
    assert_equal @item.itemcode, inventory.itemcode
  end

  test "save flags the created itemin as imported" do
    data = {
      operationtype_id: 1,
      warehouse_id: @warehouse.id,
      rows: [
        {
          _index: 1,
          _valid: true,
          _item_id: @item.id,
          "Item Code:" => @item.gencode,
          "Qt." => 5
        }
      ]
    }

    ImportInventoryService.new.save(data, @user)

    itemin = Itemin.find_by(notes: "Importazione Excel")
    assert_not_nil itemin
    assert_equal true, itemin.imported
  end

  test "save for uscita flags the created itemout as imported" do
    StockLevel.create!(gencode: @item.gencode, warehouse_id: @warehouse.id, location_id: 0, current_qty: 10)
    data = {
      operationtype_id: 2,
      warehouse_id: @warehouse.id,
      rows: [
        {
          _index: 1,
          _valid: true,
          _item_id: @item.id,
          "Item Code:" => @item.gencode,
          "Qt." => 3
        }
      ]
    }

    stats = ImportInventoryService.new.save(data, @user)

    assert_equal 1, stats[:created]
    itemout = Itemout.find_by(notes: "Importazione Excel")
    assert_not_nil itemout
    assert_equal true, itemout.imported
  end

  test "create_missing_items creates distinct items and revalidates rows" do
    data = {
      operationtype_id: 1,
      warehouse_id: @warehouse.id,
      rows: [
        {
          _index: 1, _valid: false, _error: "Articolo A1 non trovato",
          "Item Code:" => "A1", "Fabric code:" => "F1", "var. code:" => "V1",
          "Description: " => "Desc A1", "Tg." => "unique", "Note:" => "Coll Nuova", "Qt." => 2
        },
        {
          _index: 2, _valid: false, _error: "Articolo A1 non trovato",
          "Item Code:" => "A1", "Fabric code:" => "F1", "var. code:" => "V1",
          "Description: " => "Desc A1", "Note:" => "Coll Nuova", "Qt." => 5
        },
        {
          _index: 3, _valid: false, _error: "Item code mancante", "Qt." => 1
        },
        {
          _index: 4, _valid: true, "Item Code:" => "OK1", "Qt." => 1
        }
      ]
    }

    stats = ImportInventoryService.new.create_missing_items(data)

    assert_equal 1, stats[:created]
    assert_empty stats[:failed]

    item = Item.find_by(itemcode: "A1")
    assert_not_nil item
    assert_equal "F1", item.fabricode
    assert_equal "V1", item.varcode
    assert_equal "Desc A1", item.description
    assert_equal "unique", item.tg
    assert_equal "Coll Nuova", item.collection.description

    assert_equal true, data[:rows][0][:_valid]
    assert_equal item.id, data[:rows][0][:_item_id]
    assert_equal true, data[:rows][1][:_valid]
    assert_equal false, data[:rows][2][:_valid]
    assert_equal true, data[:rows][3][:_valid]
  end

  test "create_missing_items keeps rows invalid when the collection is missing" do
    data = {
      operationtype_id: 1,
      warehouse_id: @warehouse.id,
      rows: [
        {
          _index: 1, _valid: false, _error: "Articolo B1 non trovato",
          "Item Code:" => "B1", "Qt." => 1
        }
      ]
    }

    stats = ImportInventoryService.new.create_missing_items(data)

    assert_equal 0, stats[:created]
    assert_equal 1, stats[:failed].size
    assert_equal false, data[:rows][0][:_valid]
    assert_nil Item.find_by(itemcode: "B1")
  end
end
