require "test_helper"

class MovementCreationServiceTest < ActiveSupport::TestCase
  setup do
    @item = items(:one)
    @warehouse = warehouses(:one)
    @location = locations(:one)
    @operationtype = operationtypes(:one)
  end

  test "creates an inbound movement and inventory records" do
    params = {
      indate: Date.current,
      operator_id: users(:one).id,
      itemins_details_attributes: {
        "0" => {
          itemcode: @item.gencode,
          item_id: @item.id,
          qty: 3,
          warehouse_id: @warehouse.id,
          location_id: @location.id,
          operationtype_id: @operationtype.id
        }
      }
    }

    assert_difference("Itemin.count", 1) do
      assert_difference("Inventory.count", 1) do
        result = MovementCreationService.new(Itemin, params).call

        assert result.success, "Expected success, got: #{result.movement.errors.full_messages.to_sentence}"
        assert result.movement.persisted?
        assert_equal 1, result.movement.itemins_details.size
      end
    end
  end

  test "creates an outbound movement and inventory records" do
    StockLevel.create!(gencode: @item.gencode, warehouse_id: @warehouse.id, location_id: @location.id, current_qty: 10)

    params = {
      indate: Date.current,
      operator_id: users(:one).id,
      itemouts_details_attributes: {
        "0" => {
          itemcode: @item.itemcode,
          item_id: @item.id,
          qty: 2,
          warehouse_id: @warehouse.id,
          location_id: @location.id,
          operationtype_id: @operationtype.id
        }
      }
    }

    assert_difference("Itemout.count", 1) do
      assert_difference("Inventory.count", 1) do
        result = MovementCreationService.new(Itemout, params).call

        assert result.success
        assert result.movement.persisted?
      end
    end
  end

  test "returns failure for invalid movement without creating records" do
    params = {
      indate: Date.current,
      itemins_details_attributes: {}
    }

    assert_no_difference("Itemin.count") do
      assert_no_difference("Inventory.count") do
        result = MovementCreationService.new(Itemin, params).call

        assert_not result.success
        assert_not result.movement.valid?
      end
    end
  end

  test "applies warehouse and location defaults when provided" do
    params = {
      indate: Date.current,
      operator_id: users(:one).id,
      itemins_details_attributes: {
        "0" => {
          itemcode: @item.gencode,
          item_id: @item.id,
          qty: 1,
          operationtype_id: @operationtype.id
        }
      }
    }

    result = MovementCreationService.new(Itemin, params, defaults: {
      warehouse_id: @warehouse.id,
      location_id: @location.id
    }).call

    assert result.success
    detail = result.movement.itemins_details.first
    assert_equal @warehouse.id, detail.warehouse_id
    assert_equal @location.id, detail.location_id
    assert_equal @operationtype.id, detail.operationtype_id
  end
end
