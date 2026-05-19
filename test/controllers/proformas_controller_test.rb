require "test_helper"

class Production::ProformasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @proforma = proformas(:one)
  end

  test "should get index" do
    get production_proformas_url
    assert_response :success
  end

  test "should get new" do
    get new_production_proforma_url
    assert_response :success
  end

  test "should create proforma" do
    assert_difference("Proforma.count") do
      post production_proformas_url, params: { proforma: { closed: @proforma.closed, customer: @proforma.customer, data_in: @proforma.data_in, data_out: @proforma.data_out, note: @proforma.note } }
    end

    assert_redirected_to production_proforma_url(Proforma.last)
  end

  test "should show proforma" do
    get production_proforma_url(@proforma)
    assert_response :success
  end

  test "should get edit" do
    get edit_production_proforma_url(@proforma)
    assert_response :success
  end

  test "should update proforma" do
    patch production_proforma_url(@proforma), params: { proforma: { closed: @proforma.closed, customer: @proforma.customer, data_in: @proforma.data_in, data_out: @proforma.data_out, note: @proforma.note } }
    assert_redirected_to production_proforma_url(@proforma)
  end

  test "should destroy proforma" do
    assert_difference("Proforma.count", -1) do
      delete production_proforma_url(@proforma)
    end

    assert_redirected_to production_proformas_url
  end
end
