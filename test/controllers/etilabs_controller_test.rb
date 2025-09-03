require "test_helper"

class EtilabsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @etilab = etilabs(:one)
  end

  test "should get index" do
    get etilabs_url
    assert_response :success
  end

  test "should get new" do
    get new_etilab_url
    assert_response :success
  end

  test "should create etilab" do
    assert_difference("Etilab.count") do
      post etilabs_url, params: { etilab: { color: @etilab.color, customer: @etilab.customer, description: @etilab.description, fabricode: @etilab.fabricode, group: @etilab.group, itemcode: @etilab.itemcode, materiale: @etilab.materiale, qty: @etilab.qty, supplier: @etilab.supplier, tg: @etilab.tg, varcode: @etilab.varcode } }
    end

    assert_redirected_to etilab_url(Etilab.last)
  end

  test "should show etilab" do
    get etilab_url(@etilab)
    assert_response :success
  end

  test "should get edit" do
    get edit_etilab_url(@etilab)
    assert_response :success
  end

  test "should update etilab" do
    patch etilab_url(@etilab), params: { etilab: { color: @etilab.color, customer: @etilab.customer, description: @etilab.description, fabricode: @etilab.fabricode, group: @etilab.group, itemcode: @etilab.itemcode, materiale: @etilab.materiale, qty: @etilab.qty, supplier: @etilab.supplier, tg: @etilab.tg, varcode: @etilab.varcode } }
    assert_redirected_to etilab_url(@etilab)
  end

  test "should destroy etilab" do
    assert_difference("Etilab.count", -1) do
      delete etilab_url(@etilab)
    end

    assert_redirected_to etilabs_url
  end
end
