require "test_helper"

class FabriclusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fabriclu = fabriclus(:one)
  end

  test "should get index" do
    get fabriclus_url
    assert_response :success
  end

  test "should get new" do
    get new_fabriclu_url
    assert_response :success
  end

  test "should create fabriclu" do
    assert_difference("Fabriclu.count") do
      post fabriclus_url, params: { fabriclu: { color: @fabriclu.color, customer: @fabriclu.customer, description: @fabriclu.description, fab: @fabriclu.fab, materiale: @fabriclu.materiale, note: @fabriclu.note, qty: @fabriclu.qty, supplier: @fabriclu.supplier, tg: @fabriclu.tg, var: @fabriclu.var, year: @fabriclu.year } }
    end

    assert_redirected_to fabriclu_url(Fabriclu.last)
  end

  test "should show fabriclu" do
    get fabriclu_url(@fabriclu)
    assert_response :success
  end

  test "should get edit" do
    get edit_fabriclu_url(@fabriclu)
    assert_response :success
  end

  test "should update fabriclu" do
    patch fabriclu_url(@fabriclu), params: { fabriclu: { color: @fabriclu.color, customer: @fabriclu.customer, description: @fabriclu.description, fab: @fabriclu.fab, materiale: @fabriclu.materiale, note: @fabriclu.note, qty: @fabriclu.qty, supplier: @fabriclu.supplier, tg: @fabriclu.tg, var: @fabriclu.var, year: @fabriclu.year } }
    assert_redirected_to fabriclu_url(@fabriclu)
  end

  test "should destroy fabriclu" do
    assert_difference("Fabriclu.count", -1) do
      delete fabriclu_url(@fabriclu)
    end

    assert_redirected_to fabriclus_url
  end
end
