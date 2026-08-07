require "test_helper"

class MovementBuilderTest < ActiveSupport::TestCase
  setup do
    @item = items(:one)
    @warehouse = warehouses(:one)
    @location = locations(:one)
    @operationtype = operationtypes(:one)
  end

  test "builds an Itemin with details from params" do
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

    movement = MovementBuilder.new(Itemin, params).build

    assert_instance_of Itemin, movement
    assert_equal Date.current, movement.indate
    assert_equal 1, movement.itemins_details.size
    detail = movement.itemins_details.first
    assert_equal @item.id, detail.item_id
    assert_equal 3, detail.qty
    assert_equal @warehouse.id, detail.warehouse_id
  end

  test "normalizes a HashWithIndifferentAccess from session" do
    params = ActionController::Parameters.new(
      indate: Date.current,
      itemouts_details_attributes: {
        "0" => {
          itemcode: @item.itemcode,
          item_id: @item.id,
          qty: 1,
          warehouse_id: @warehouse.id,
          location_id: @location.id,
          operationtype_id: @operationtype.id
        }
      }
    ).to_unsafe_h.with_indifferent_access

    movement = MovementBuilder.new(Itemout, params).build

    assert_instance_of Itemout, movement
    assert_equal 1, movement.itemouts_details.size
  end

  test "rejects destroyed and empty rows" do
    params = {
      itemins_details_attributes: {
        "0" => { item_id: @item.id, _destroy: "1" },
        "1" => { itemcode: "" },
        "2" => {
          itemcode: @item.gencode,
          item_id: @item.id,
          qty: 1,
          warehouse_id: @warehouse.id,
          location_id: @location.id,
          operationtype_id: @operationtype.id
        }
      }
    }

    movement = MovementBuilder.new(Itemin, params).build

    assert_equal 1, movement.itemins_details.size
  end

  test "applies defaults when detail values are blank" do
    params = {
      indate: Date.current,
      itemins_details_attributes: {
        "0" => {
          itemcode: @item.gencode,
          item_id: @item.id,
          qty: 2,
          operationtype_id: @operationtype.id
        }
      }
    }

    movement = MovementBuilder.new(Itemin, params, defaults: {
      warehouse_id: @warehouse.id,
      location_id: @location.id
    }).build

    detail = movement.itemins_details.first
    assert_equal @warehouse.id, detail.warehouse_id
    assert_equal @location.id, detail.location_id
  end

  test "sets default operationtype for Itemout when missing" do
    params = {
      itemouts_details_attributes: {
        "0" => {
          itemcode: @item.itemcode,
          item_id: @item.id,
          qty: 1,
          warehouse_id: @warehouse.id,
          location_id: @location.id
        }
      }
    }

    movement = MovementBuilder.new(Itemout, params).build

    assert_equal 2, movement.itemouts_details.first.operationtype_id
  end

  test "filter_details returns only the detail hashes" do
    params = {
      itemmovements_details_attributes: {
        "0" => {
          itemcode: @item.gencode,
          item_id: @item.id,
          qty: 1,
          warehouse_id: @warehouse.id,
          location_id: @location.id,
          operationtype_id: 1
        }
      }
    }

    details = MovementBuilder.filter_details(Itemmovement, params)

    assert_equal 1, details.size
    assert_equal @item.id, details.first[:item_id]
  end
end
