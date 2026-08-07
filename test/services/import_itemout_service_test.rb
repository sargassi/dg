require "test_helper"

class ImportItemoutServiceTest < ActiveSupport::TestCase
  setup do
    @item = items(:one)
    @user = users(:one)
    @warehouse = warehouses(:one)
    @warehouse.update!(code: "UCCITE")
    Operationtype.find_or_create_by!(id: 2) do |op|
      op.code = "O"
      op.description = "Uscita"
    end
  end

  test "validate_row marks as invalid without an item code" do
    service = ImportItemoutService.new
    row = { "Item Code:" => "" }
    service.validate_row(row)
    assert_equal false, row[:_valid]
    assert_not_nil row[:_error]
  end

  test "validate_row flags a missing item" do
    service = ImportItemoutService.new
    row = { "Item Code:" => "NOSUCHITEM", "esce" => "15/03/2026" }
    service.validate_row(row)
    assert_equal false, row[:_valid]
    assert_equal "Articolo NOSUCHITEM non trovato", row[:_error]
  end

  test "validate_row accepts a valid item with a parses date" do
    service = ImportItemoutService.new
    row = {
      "Item Code:" => @item.itemcode,
      "esce data:" => "15/03/2026"
    }
    service.validate_row(row)
    assert_equal true, row[:_valid]
    assert_equal @item.id, row[:_item_id]
    assert_equal Date.new(2026, 3, 15), row[:_date]
  end

  test "save creates one Itemout per date and adjusts stock" do
    StockLevel.create!(gencode: @item.gencode, warehouse_id: @warehouse.id, location_id: 0, current_qty: 10)

    data = {
      rows: [
        {
          _index: 1, _valid: true, _item_id: @item.id, _itemcode: @item.itemcode,
          _gencode: @item.gencode, _date: Date.new(2026, 3, 15), _qty: 1,
          "Item Code:" => @item.itemcode, "dove" => @warehouse.code
        },
        {
          _index: 2, _valid: true, _item_id: @item.id, _itemcode: @item.itemcode,
          _gencode: @item.gencode, _date: Date.new(2026, 3, 15), _qty: 1,
          "Item Code:" => @item.itemcode, "dove" => @warehouse.code
        },
        {
          _index: 3, _valid: true, _item_id: @item.id, _itemcode: @item.itemcode,
          _gencode: @item.gencode, _date: Date.new(2026, 3, 16), _qty: 1,
          "Item Code:" => @item.itemcode, "dove" => @warehouse.code
        }
      ]
    }

    stats = ImportItemoutService.new.save(data, @user)

    assert_equal 3, stats[:created]
    assert_equal 2, stats[:itemouts].size
    assert_equal 4, Itemout.count
    assert_equal 7, StockLevel.find_by(gencode: @item.gencode, warehouse_id: @warehouse.id).current_qty
  end

  test "save collects rows missing a warehouse as invalid" do
    data = {
      rows: [
        {
          _index: 1, _valid: true, _item_id: @item.id, _itemcode: @item.itemcode,
          _gencode: @item.gencode, _date: Date.new(2026, 3, 15), _qty: 1,
          "Item Code:" => @item.itemcode, "dove" => ""
        }
      ]
    }

    stats = ImportItemoutService.new.save(data, @user)

    assert_equal 0, stats[:created]
    assert_equal 1, stats[:invalid].size
    assert_includes stats[:invalid].first[:error], "Magazzino"
  end
end