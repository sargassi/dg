require "test_helper"

class CreateQrServiceTest < ActiveSupport::TestCase
  test "call returns a PNG over 500 bytes" do
    png = CreateQrService.new.call("TEST_GENCODE")
    assert_instance_of ChunkyPNG::Image, png
    assert_equal 120, png.width
    assert_equal 120, png.height
  end

  test "svg returns a string containing an svg tag" do
    svg = CreateQrService.new.svg("TEST_GENCODE")
    assert_includes svg, "<svg"
    assert_not_includes svg, "<?xml"
    assert_not_includes svg, "<?xml version"
  end

  test "generates distinct svg for different codes" do
    one = CreateQrService.new.svg("ABC123")
    two = CreateQrService.new.svg("XYZ789")
    assert_not_equal one, two
  end
end