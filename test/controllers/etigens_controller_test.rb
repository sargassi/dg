require "test_helper"

class EtigensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @etigen = etigens(:one)
  end

  test "should get index" do
    get etigens_url
    assert_response :success
  end

  test "should get new" do
    get new_etigen_url
    assert_response :success
  end

  test "should create etigen" do
    assert_difference("Etigen.count") do
      post etigens_url, params: { etigen: { group: @etigen.group, qty: @etigen.qty, riga1: @etigen.riga1, riga2: @etigen.riga2, riga3: @etigen.riga3, riga4: @etigen.riga4, riga5: @etigen.riga5, status: @etigen.status } }
    end

    assert_redirected_to etigen_url(Etigen.last)
  end

  test "should show etigen" do
    get etigen_url(@etigen)
    assert_response :success
  end

  test "should get edit" do
    get edit_etigen_url(@etigen)
    assert_response :success
  end

  test "should update etigen" do
    patch etigen_url(@etigen), params: { etigen: { group: @etigen.group, qty: @etigen.qty, riga1: @etigen.riga1, riga2: @etigen.riga2, riga3: @etigen.riga3, riga4: @etigen.riga4, riga5: @etigen.riga5, status: @etigen.status } }
    assert_redirected_to etigen_url(@etigen)
  end

  test "should destroy etigen" do
    assert_difference("Etigen.count", -1) do
      delete etigen_url(@etigen)
    end

    assert_redirected_to etigens_url
  end
end
