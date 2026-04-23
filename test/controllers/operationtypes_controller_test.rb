require "test_helper"

class OperationtypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @operationtype = operationtypes(:one)
  end

  test "should get index" do
    get operationtypes_url
    assert_response :success
  end

  test "should get new" do
    get new_operationtype_url
    assert_response :success
  end

  test "should create operationtype" do
    assert_difference("Operationtype.count") do
      post operationtypes_url, params: { operationtype: { code: @operationtype.code, description: @operationtype.description } }
    end

    assert_redirected_to operationtype_url(Operationtype.last)
  end

  test "should show operationtype" do
    get operationtype_url(@operationtype)
    assert_response :success
  end

  test "should get edit" do
    get edit_operationtype_url(@operationtype)
    assert_response :success
  end

  test "should update operationtype" do
    patch operationtype_url(@operationtype), params: { operationtype: { code: @operationtype.code, description: @operationtype.description } }
    assert_redirected_to operationtype_url(@operationtype)
  end

  test "should destroy operationtype" do
    assert_difference("Operationtype.count", -1) do
      delete operationtype_url(@operationtype)
    end

    assert_redirected_to operationtypes_url
  end
end
