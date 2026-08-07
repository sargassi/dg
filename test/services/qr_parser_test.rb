require "test_helper"

class QrParserTest < ActiveSupport::TestCase
  test "parses a 3-part code with collection and detail id" do
    parsed = QrParser.parse("GENCODE_0042_17")
    assert_equal "GENCODE", parsed[:gencode]
    assert_equal 42, parsed[:collection_id]
    assert_equal 17, parsed[:detail_id]
  end

  test "parses a 2-part code with detail id when gencode ends in _digits" do
    parsed = QrParser.parse("a127cb wl248.1.27_51_17")
    assert_equal "a127cb wl248.1.27_51", parsed[:gencode]
    assert_nil parsed[:collection_id]
    assert_equal 17, parsed[:detail_id]
  end

  test "leaves a trailing _digits code intact when it is just a gencode" do
    parsed = QrParser.parse("a127cb wl248.1.27_51")
    assert_equal "a127cb wl248.1.27_51", parsed[:gencode]
    assert_nil parsed[:collection_id]
    assert_nil parsed[:detail_id]
  end

  test "returns gencode only for plain text" do
    parsed = QrParser.parse("PLAIN-GENCODE")
    assert_equal "PLAIN-GENCODE", parsed[:gencode]
    assert_nil parsed[:collection_id]
    assert_nil parsed[:detail_id]
  end
end