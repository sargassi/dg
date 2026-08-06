require "test_helper"

class StockLevelTest < ActiveSupport::TestCase
  setup do
    @warehouse = warehouses(:one)
    @location = locations(:one)
  end

  def build_stock_level(attrs = {})
    StockLevel.new({
      gencode: "TEST",
      warehouse: @warehouse,
      location: @location,
      current_qty: 10
    }.merge(attrs))
  end

  test "valid with required fields" do
    assert build_stock_level.valid?
  end

  test "invalid without warehouse" do
    refute build_stock_level(warehouse: nil).valid?
  end

  test "default location_id is 0" do
    sl = StockLevel.new(gencode: "TEST", warehouse: @warehouse)
    assert_equal 0, sl.location_id
  end

  test "default current_qty is 0" do
    sl = StockLevel.new(gencode: "TEST", warehouse: @warehouse)
    assert_equal 0, sl.current_qty
  end

  test "positive scope filters zero/negative" do
    StockLevel.create!(gencode: "POS", warehouse: @warehouse, location: @location, current_qty: 5)
    StockLevel.create!(gencode: "ZERO", warehouse: @warehouse, location: @location, current_qty: 0)
    StockLevel.create!(gencode: "NEG", warehouse: @warehouse, location: @location, current_qty: -3)
    assert_equal 1, StockLevel.positive.count
  end

  test "adjust_qty! increments existing level" do
    StockLevel.create!(gencode: "ADJ", warehouse: @warehouse, location: @location, current_qty: 10)
    StockLevel.adjust_qty!("ADJ", @warehouse.id, @location.id, 5)
    assert_equal 15, StockLevel.find_by!(gencode: "ADJ", warehouse: @warehouse).current_qty
  end

  test "adjust_qty! creates a level on first inbound" do
    assert_difference("StockLevel.count", 1) do
      StockLevel.adjust_qty!("NEW", @warehouse.id, @location.id, 4)
    end
    assert_equal 4, StockLevel.find_by!(gencode: "NEW", warehouse: @warehouse).current_qty
  end

  test "adjust_qty! raises when delta would drive stock negative" do
    StockLevel.create!(gencode: "LOW", warehouse: @warehouse, location: @location, current_qty: 2)
    assert_raises(StockLevel::InsufficientStockError) do
      StockLevel.adjust_qty!("LOW", @warehouse.id, @location.id, -3)
    end
    assert_equal 2, StockLevel.find_by!(gencode: "LOW", warehouse: @warehouse).current_qty
  end

  test "adjust_qty! raises for negative delta on missing level" do
    assert_raises(StockLevel::InsufficientStockError) do
      StockLevel.adjust_qty!("GHOST", @warehouse.id, @location.id, -1)
    end
  end
end
