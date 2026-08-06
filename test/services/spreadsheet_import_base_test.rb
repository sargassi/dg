require "test_helper"

class SpreadsheetImportBaseTest < ActiveSupport::TestCase
  class StubSpreadsheet
    def initialize(rows)
      @rows = rows
    end

    def last_row
      @rows.size
    end

    def row(i)
      @rows[i - 1]
    end
  end

  class TestService < SpreadsheetImportBase
    def known_headers
      ['Item Code:', 'Qt.']
    end
  end

  setup do
    @service = TestService.new
  end

  test "cell matches keys case-insensitively" do
    row = { "ITEM CODE:" => "ABC", "Qt." => 3 }

    assert_equal "ABC", @service.cell(row, 'Item Code:')
    assert_equal "ABC", @service.cell(row, 'itemcode', 'Item Code:')
  end

  test "cell falls back through keys and prefers an exact key" do
    row = { "Quantity" => 7 }

    assert_equal 7, @service.cell(row, 'Qt.', 'Quantity')
    assert_nil @service.cell(row, 'Qt.', 'QTA')
  end

  test "find_header_row matches headers case-insensitively" do
    spreadsheet = StubSpreadsheet.new([
      ["boh", "altro"],
      ["item code:", "QT."],
      ["A", 1],
      ["B", 2]
    ])

    assert_equal 2, @service.find_header_row(spreadsheet)
  end

  test "find_header_row defaults to first row when no headers match" do
    spreadsheet = StubSpreadsheet.new([
      ["nothing", "here"],
      ["A", 1]
    ])

    assert_equal 1, @service.find_header_row(spreadsheet)
  end

  test "find_or_create_warehouse creates and reuses by code" do
    w1 = @service.find_or_create_warehouse("MAGX")
    w2 = @service.find_or_create_warehouse("MAGX")

    assert_equal w1, w2
    assert_equal "MAGX", w1.code
    assert w1.enabled
  end

  test "find_or_create_warehouse returns nil for blank code" do
    assert_nil @service.find_or_create_warehouse("   ")
  end

  test "find_or_create_collection creates and reuses by description" do
    c1 = @service.find_or_create_collection("Collezione Prova")
    c2 = @service.find_or_create_collection("Collezione Prova")

    assert_equal c1, c2
    assert_equal "Collezione Prova", c1.description
  end

  test "extract_error prefers record errors over the message" do
    item = Item.new
    item.errors.add(:itemcode, "è obbligatorio")
    error = ActiveRecord::RecordInvalid.new(item)

    assert_equal "Itemcode è obbligatorio", @service.extract_error(error)
  end

  test "extract_error falls back to message when no record" do
    error = StandardError.new("generic failure")

    assert_equal "generic failure", @service.extract_error(error)
  end
end
