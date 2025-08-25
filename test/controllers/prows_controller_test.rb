require "test_helper"

class ProwsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @prow = prows(:one)
  end

  test "should get index" do
    get prows_url
    assert_response :success
  end

  test "should get new" do
    get new_prow_url
    assert_response :success
  end

  test "should create prow" do
    assert_difference("Prow.count") do
      post prows_url, params: { prow: { code: @prow.code, description: @prow.description, note: @prow.note, proforma_id: @prow.proforma_id, qr: @prow.qr, qty: @prow.qty } }
    end

    assert_redirected_to prow_url(Prow.last)
  end

  test "should show prow" do
    get prow_url(@prow)
    assert_response :success
  end

  test "should get edit" do
    get edit_prow_url(@prow)
    assert_response :success
  end

  test "should update prow" do
    patch prow_url(@prow), params: { prow: { code: @prow.code, description: @prow.description, note: @prow.note, proforma_id: @prow.proforma_id, qr: @prow.qr, qty: @prow.qty } }
    assert_redirected_to prow_url(@prow)
  end

  test "should destroy prow" do
    assert_difference("Prow.count", -1) do
      delete prow_url(@prow)
    end

    assert_redirected_to prows_url
  end
end
