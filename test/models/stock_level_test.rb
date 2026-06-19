require "test_helper"

class StockLevelTest < ActiveSupport::TestCase
  test "valid with required fields" do
    sl = StockLevel.new(gencode: "TEST", warehouse_id: 1, current_qty: 10)
    assert sl.valid?
  end

  test "invalid without gencode" do
    sl = StockLevel.new(warehouse_id: 1, current_qty: 10)
    refute sl.valid?
  end

  test "invalid without warehouse_id" do
    sl = StockLevel.new(gencode: "TEST", current_qty: 10)
    refute sl.valid?
  end

  test "default location_id is 0" do
    sl = StockLevel.new(gencode: "TEST", warehouse_id: 1, current_qty: 10)
    assert_equal 0, sl.location_id
  end

  test "default current_qty is 0" do
    sl = StockLevel.new(gencode: "TEST", warehouse_id: 1)
    assert_equal 0, sl.current_qty
  end

  test "positive scope filters zero/negative" do
    StockLevel.create!(gencode: "POS", warehouse_id: 1, current_qty: 5)
    StockLevel.create!(gencode: "ZERO", warehouse_id: 1, current_qty: 0)
    StockLevel.create!(gencode: "NEG", warehouse_id: 1, current_qty: -3)
    assert_equal 1, StockLevel.positive.count
  end
end
