require "test_helper"

class ImportLogsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get import_logs_url
    assert_response :success
  end

  test "should show import_log" do
    log = ImportLog.create!(
      user: users(:one),
      file_name: "test.xlsx",
      total_rows: 10,
      status: 'completed'
    )
    get import_log_url(log)
    assert_response :success
  end
end
