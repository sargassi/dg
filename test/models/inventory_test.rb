require "test_helper"

class InventoryTest < ActiveSupport::TestCase
  setup do
    @warehouse = warehouses(:one)
    @location = locations(:one)
    @operationtype = operationtypes(:one)
    @itemin = itemins(:one)
  end

  def build_inventory(attrs = {})
    Inventory.new({
      gencode: "GCODE1",
      qtyavailable: 5,
      warehouse: @warehouse,
      location: @location,
      operationtype: @operationtype,
      itemin: @itemin
    }.merge(attrs))
  end

  test "valid with all required fields" do
    assert build_inventory.valid?
  end

  test "invalid without gencode" do
    refute build_inventory(gencode: nil).valid?
  end

  test "invalid with non-numeric qtyavailable" do
    refute build_inventory(qtyavailable: "abc").valid?
  end

  test "invalid without warehouse" do
    refute build_inventory(warehouse: nil).valid?
  end

  test "invalid when more than one movement origin is set" do
    inventory = build_inventory
    inventory.itemout = itemouts(:one)
    refute inventory.valid?
    assert_includes inventory.errors[:base], "Un inventario può riferirsi a un solo movimento"
  end

  test "valid with a single movement origin" do
    assert build_inventory.valid?
  end
end
