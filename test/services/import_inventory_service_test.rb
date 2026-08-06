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
end
