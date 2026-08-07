require "test_helper"

class AppControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

  test "should get dashboard" do
    get app_dashboard_url
    assert_response :success
  end

  test "should get sez" do
    get app_sez_url
    assert_response :success
  end

  test "in_warehouse tracks return_to and shows Annulla" do
    get app_in_warehouse_url(return_to: inventories_seleziona_path)
    assert_response :success
    assert_select "input[name='return_to'][value=?]", inventories_seleziona_path
    assert_select "a", text: /Annulla/
  end

  test "out_warehouse tracks return_to and shows Annulla" do
    get app_out_warehouse_url(return_to: inventories_dashboard_path)
    assert_response :success
    assert_select "input[name='return_to'][value=?]", inventories_dashboard_path
    assert_select "a", text: /Annulla/
  end
  test "move_products tracks return_to and shows Annulla" do
    get app_move_products_url(return_to: inventories_dashboard_path)

    assert_response :success
    assert_select "input[name='return_to'][value=?]", inventories_dashboard_path
    assert_select "a", text: /Annulla/
  end

  test "post in_warehouse creates a load and redirects to return_to" do
    assert_difference("Itemin.count", 1) do
      post app_in_warehouse_url(return_to: inventories_dashboard_path), params: {
        itemin: {
          indate: Date.current,
          itemins_details_attributes: {
            "0" => {
              itemcode: items(:one).gencode,
              item_id: items(:one).id,
              qty: 2,
              warehouse_id: warehouses(:one).id,
              location_id: locations(:one).id,
              operationtype_id: operationtypes(:one).id,
              _destroy: "0"
            }
          }
        }
      }
    end

    assert_redirected_to inventories_dashboard_path
    assert_equal "Carico creato con successo.", flash[:notice]
  end

  test "post out_warehouse creates an unload and redirects to return_to" do
    StockLevel.create!(gencode: items(:one).gencode, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, current_qty: 10)

    assert_difference("Itemout.count", 1) do
      post app_out_warehouse_url(return_to: inventories_dashboard_path), params: {
        itemout: {
          indate: Date.current,
          itemouts_details_attributes: {
            "0" => {
              itemcode: items(:one).itemcode,
              item_id: items(:one).id,
              qty: 1,
              warehouse_id: warehouses(:one).id,
              location_id: locations(:one).id,
              operationtype_id: operationtypes(:one).id,
              _destroy: "0"
            }
          }
        }
      }
    end

    assert_redirected_to inventories_dashboard_path
    assert_equal "Scarico creato con successo.", flash[:notice]
  end

  test "should get mobile_in" do
    get app_mobile_in_url
    assert_response :success
    assert_select "[data-mobile-wizard-target='step']", count: 2
    assert_match app_mobile_out_path, response.body
    assert_match app_mobile_var_path, response.body
  end

  test "should get mobile_out" do
    get app_mobile_out_url
    assert_response :success
  end

  test "should get mobile_var" do
    get app_mobile_var_url
    assert_response :success
    assert_select "[data-mobile-wizard-target='step']", count: 3
  end

  test "post mobile_in creates a load and redirects to mobile_in_confirmation" do
    assert_difference("Itemin.count", 1) do
      post app_mobile_in_url, params: {
        default_warehouse_id: warehouses(:one).id,
        default_location_id: locations(:one).id,
        itemin: {
          indate: Date.current,
          itemins_details_attributes: {
            "0" => {
              itemcode: items(:one).gencode,
              item_id: items(:one).id,
              qty: 2,
              warehouse_id: warehouses(:one).id,
              location_id: locations(:one).id,
              operationtype_id: operationtypes(:one).id,
              _destroy: "0"
            }
          }
        }
      }
    end

    assert_redirected_to app_mobile_in_confirmation_url(itemin_id: Itemin.last.id)
    assert_equal "Carico creato con successo.", flash[:notice]
  end

  test "post mobile_out creates an unload and redirects to mobile_out_confirmation" do
    StockLevel.create!(gencode: items(:one).gencode, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, current_qty: 10)

    assert_difference("Itemout.count", 1) do
      post app_mobile_out_url, params: {
        default_warehouse_id: warehouses(:one).id,
        default_location_id: locations(:one).id,
        itemout: {
          indate: Date.current,
          itemouts_details_attributes: {
            "0" => {
              itemcode: items(:one).itemcode,
              item_id: items(:one).id,
              qty: 1,
              warehouse_id: warehouses(:one).id,
              location_id: locations(:one).id,
              operationtype_id: operationtypes(:two).id,
              _destroy: "0"
            }
          }
        }
      }
    end

    assert_redirected_to app_mobile_out_confirmation_url(itemout_id: Itemout.last.id)
    assert_equal "Scarico creato con successo.", flash[:notice]
  end

  test "post mobile_var creates a movement and redirects to mobile_var_confirmation" do
    StockLevel.create!(gencode: items(:one).gencode, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, current_qty: 10)
    Operationtype.find_or_create_by!(id: 1) { |op| op.code = "carico" }
    Operationtype.find_or_create_by!(id: 2) { |op| op.code = "scarico" }

    assert_difference("Itemmovement.count", 1) do
      post app_mobile_var_url, params: {
        source_warehouse_id: warehouses(:one).id,
        source_location_id: locations(:one).id,
        dest_warehouse_id: warehouses(:two).id,
        dest_location_id: locations(:two).id,
        itemmovement: {
          indate: Date.current,
          itemmovements_details_attributes: {
            "0" => {
              itemcode: items(:one).itemcode,
              item_id: items(:one).id,
              qty: 1,
              warehouse_id: warehouses(:one).id,
              location_id: locations(:one).id,
              operationtype_id: 3,
              _destroy: "0"
            }
          }
        }
      }
    end

    assert_redirected_to app_mobile_var_confirmation_url(ids: Itemmovement.last.id.to_s)
    assert_equal "Spostamento creato con successo.", flash[:notice]
  end

  test "post mobile_var without destination re-renders wizard with alert" do
    post app_mobile_var_url, params: {
      source_warehouse_id: warehouses(:one).id,
      source_location_id: locations(:one).id,
      itemmovement: {
        indate: Date.current,
        itemmovements_details_attributes: {
          "0" => { itemcode: items(:one).itemcode, item_id: items(:one).id, qty: 1, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, operationtype_id: 3, _destroy: "0" }
        }
      }
    }

    assert_response :unprocessable_entity
    assert_select "span", text: /Seleziona un magazzino di destinazione/
  end

  test "post mobile_var without source location re-renders wizard with stock alert" do
    # Ubica is optional: with no stock at warehouse level the stock check
    # fires instead of a location guard.
    post app_mobile_var_url, params: {
      source_warehouse_id: warehouses(:one).id,
      dest_warehouse_id: warehouses(:two).id,
      itemmovement: {
        indate: Date.current,
        itemmovements_details_attributes: {
          "0" => { itemcode: items(:one).itemcode, item_id: items(:one).id, qty: 1, warehouse_id: warehouses(:one).id, operationtype_id: 3, _destroy: "0" }
        }
      }
    }

    assert_response :unprocessable_entity
    assert_select "span", text: /supera la disponibilità/
  end

  test "post mobile_var with insufficient stock re-renders wizard with alert" do
    StockLevel.create!(gencode: items(:one).gencode, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, current_qty: 1)

    post app_mobile_var_url, params: {
      source_warehouse_id: warehouses(:one).id,
      source_location_id: locations(:one).id,
      dest_warehouse_id: warehouses(:two).id,
      dest_location_id: locations(:two).id,
      itemmovement: {
        indate: Date.current,
        itemmovements_details_attributes: {
          "0" => { itemcode: items(:one).itemcode, item_id: items(:one).id, qty: 5, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, operationtype_id: 3, _destroy: "0" }
        }
      }
    }

    assert_response :unprocessable_entity
    assert_select "span", text: /supera la disponibilità/
  end

  test "post mobile_out with insufficient stock re-renders wizard with alert" do
    StockLevel.create!(gencode: items(:one).gencode, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, current_qty: 1)

    assert_no_difference("Itemout.count") do
      post app_mobile_out_url, params: {
        default_warehouse_id: warehouses(:one).id,
        default_location_id: locations(:one).id,
        itemout: {
          indate: Date.current,
          itemouts_details_attributes: {
            "0" => { itemcode: items(:one).itemcode, item_id: items(:one).id, qty: 5, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, operationtype_id: operationtypes(:two).id, _destroy: "0" }
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "span", text: /supera la disponibilità/
  end

  test "should get mobile_print" do
    get app_mobile_print_url
    assert_response :success
  end

  test "post mobile_print without items re-renders with alert" do
    post app_mobile_print_url, params: { print: [{ item_id: "", qty: 1 }] }
    assert_response :unprocessable_entity
  end

  test "post mobile_print stores selection and redirects to confirmation" do
    post app_mobile_print_url, params: {
      print: [{ item_id: items(:one).id, itemcode: items(:one).gencode, qty: 2 }]
    }
    assert_redirected_to app_mobile_print_confirmation_url
    assert_equal [items(:one).id], session[:mobile_print_items].map { |r| r["item_id"] }
    assert_equal [2], session[:mobile_print_items].map { |r| r["qty"] }
  end

  test "should get mobile_print_confirmation" do
    post app_mobile_print_url, params: {
      print: [{ item_id: items(:one).id, itemcode: items(:one).gencode, qty: 2 }]
    }
    get app_mobile_print_confirmation_url
    assert_response :success
    assert_select "a[href*='mobile_print_label']", count: 1
  end

  test "mobile_print_confirmation without items redirects back" do
    get app_mobile_print_confirmation_url
    assert_redirected_to app_mobile_print_url
  end

  test "mobile_print_label renders a pdf label" do
    get app_mobile_print_label_url(item_id: items(:one).id, qty: 2)
    assert_response :success
  end

  test "should get mobile_reassign" do
    get app_mobile_reassign_url
    assert_response :success
  end

  test "post mobile_reassign reassigns stock and inventory and redirects" do
    StockLevel.create!(gencode: items(:one).gencode, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, current_qty: 5)
    Inventory.create!(gencode: items(:one).gencode, item_id: items(:one).id, qtyavailable: 5, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, operationtype_id: operationtypes(:one).id)

    assert_difference("Itemmovement.count", 0) do
      assert_difference("Itemin.count", 0) do
        assert_difference("Itemout.count", 0) do
          post app_mobile_reassign_url, params: {
            source_warehouse_id: warehouses(:one).id,
            source_location_id: locations(:one).id,
            dest_warehouse_id: warehouses(:two).id,
            dest_location_id: locations(:two).id,
            reassign: [{ item_id: items(:one).id }]
          }
        end
      end
    end

    assert_redirected_to app_mobile_reassign_confirm_url
    assert_equal 5, StockLevel.find_by(gencode: items(:one).gencode, warehouse_id: warehouses(:two).id, location_id: locations(:two).id).current_qty
    assert_nil StockLevel.find_by(gencode: items(:one).gencode, warehouse_id: warehouses(:one).id, location_id: locations(:one).id)
    assert_equal warehouses(:two).id, Inventory.find_by(gencode: items(:one).gencode).warehouse_id
    assert_equal locations(:two).id, Inventory.find_by(gencode: items(:one).gencode).location_id
  end

  test "post mobile_reassign without source re-renders with alert" do
    post app_mobile_reassign_url, params: {
      dest_warehouse_id: warehouses(:two).id,
      reassign: [{ item_id: items(:one).id }]
    }
    assert_response :unprocessable_entity
    assert_match "magazzino di origine", response.body
  end

  test "post mobile_reassign without destination re-renders with alert" do
    post app_mobile_reassign_url, params: {
      source_warehouse_id: warehouses(:one).id,
      reassign: [{ item_id: items(:one).id }]
    }
    assert_response :unprocessable_entity
    assert_match "magazzino di destinazione", response.body
  end

  test "post mobile_reassign without articles re-renders with alert" do
    post app_mobile_reassign_url, params: {
      source_warehouse_id: warehouses(:one).id,
      dest_warehouse_id: warehouses(:two).id,
      reassign: [{ item_id: "" }]
    }
    assert_response :unprocessable_entity
    assert_match "Nessun articolo valido", response.body
  end

  test "post mobile_reassign with no stock at source re-renders with alert" do
    post app_mobile_reassign_url, params: {
      source_warehouse_id: warehouses(:one).id,
      source_location_id: locations(:one).id,
      dest_warehouse_id: warehouses(:two).id,
      dest_location_id: locations(:two).id,
      reassign: [{ item_id: items(:one).id }]
    }
    assert_response :unprocessable_entity
    assert_match "Nessuna giacenza", response.body
  end

  test "mobile_reassign_confirm renders success page after reassign" do
    StockLevel.create!(gencode: items(:one).gencode, warehouse_id: warehouses(:one).id, location_id: locations(:one).id, current_qty: 5)

    post app_mobile_reassign_url, params: {
      source_warehouse_id: warehouses(:one).id,
      source_location_id: locations(:one).id,
      dest_warehouse_id: warehouses(:two).id,
      dest_location_id: locations(:two).id,
      reassign: [{ item_id: items(:one).id }]
    }

    get app_mobile_reassign_confirm_url
    assert_response :success
    assert_match "Riallocazione completata", response.body
    assert_match items(:one).gencode, response.body
    assert_match "5 pz", response.body
  end

  test "post mobile_reassign with identical origin and destination re-renders with alert" do
    post app_mobile_reassign_url, params: {
      source_warehouse_id: warehouses(:one).id,
      source_location_id: locations(:one).id,
      dest_warehouse_id: warehouses(:one).id,
      dest_location_id: locations(:one).id,
      reassign: [{ item_id: items(:one).id }]
    }
    assert_response :unprocessable_entity
    assert_match "coincidono", response.body
  end

  test "mobile_reassign_confirm without result redirects back" do
    get app_mobile_reassign_confirm_url
    assert_redirected_to app_mobile_reassign_url
  end
end
