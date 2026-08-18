require "test_helper"

class ImportParserTest < ActiveSupport::TestCase
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

  test "gencode_for joins codes with trailing underscore and collection" do
    row = {
      "Item Code:" => "ABC",
      "Fabric code:" => "FAB",
      "var. code:" => "01",
      _collection_id: 7
    }

    assert_equal "ABCFAB01_7", ImportParser.gencode_for(row)
  end

  test "gencode_for falls back to the supplied collection description when no collection id" do
    row = {
      "Item Code:" => "ABC",
      "Fabric code:" => "FAB",
      "var. code:" => "01"
    }

    assert_equal "ABCFAB01_Primavera", ImportParser.gencode_for(row, "Primavera")
  end

  test "gencode_for strips surrounding whitespace from codes" do
    row = {
      "Item Code:" => "  ABC ",
      "Fabric code:" => " FAB",
      "var. code:" => "01 ",
      _collection_id: 3
    }

    assert_equal "ABCFAB01_3", ImportParser.gencode_for(row)
  end

  test "gencode_for produces a trailing underscore when no collection is present" do
    row = {
      "Item Code:" => "ABC",
      "Fabric code:" => "FAB",
      "var. code:" => "01"
    }

    assert_equal "ABCFAB01_", ImportParser.gencode_for(row)
  end

  test "find_header_row locates the row matching at least two known headers" do
    spreadsheet = StubSpreadsheet.new([
      ["boh", "altro"],
      ["Item Code:", "Fabric code:", "Nome:", "Prezzo", "Note:"],
      ["A", "F1", "x", 10, "Col"]
    ])

    assert_equal 2, ImportParser.new.find_header_row(spreadsheet)
  end

  test "find_header_row defaults to the first row when no headers match" do
    spreadsheet = StubSpreadsheet.new([
      ["nothing", "here"],
      ["A", 1]
    ])

    assert_equal 1, ImportParser.new.find_header_row(spreadsheet)
  end

  test "normalize_header lowercases and strips" do
    assert_equal "item code:", ImportParser.new.normalize_header("Item Code:  ")
  end

  test "resolve_collection uses the override collection" do
    collection = collections(:one)
    parser = ImportParser.new
    row = {}

    parser.resolve_collection(row, override_collection_id: collection.id)

    assert_equal collection.id, row[:_collection_id]
    assert_equal collection.description, row[:_collection_description]
    assert_equal false, row[:_collection_new]
  end

  test "resolve_collection marks an existing collection from the Note column" do
    collection = Collection.create!(description: "MYTEXT")
    parser = ImportParser.new
    row = { "Note:" => "MyText" }

    parser.resolve_collection(row)

    assert_equal collection.id, row[:_collection_id]
    assert_equal false, row[:_collection_new]
  end

  test "resolve_collection upcases and marks a new collection but does not create it" do
    parser = ImportParser.new
    row = { "Note:" => "Collezione Inesistente 9999" }

    parser.resolve_collection(row)

    assert_nil row[:_collection_id]
    assert_equal "COLLEZIONE INESISTENTE 9999", row[:_collection_description]
    assert_equal true, row[:_collection_new]
    assert_nil Collection.find_by(description: "COLLEZIONE INESISTENTE 9999")
  end

  test "resolve_warehouse reuses an existing warehouse by code" do
    warehouse = Warehouse.create!(code: "MAGX", enabled: true)
    parser = ImportParser.new
    row = { "dove" => "MAGX" }

    parser.resolve_warehouse(row)

    assert_equal warehouse.id, row[:_warehouse_id]
    assert_equal false, row[:_warehouse_new]
  end

  test "resolve_warehouse marks a new warehouse without creating it" do
    parser = ImportParser.new
    row = { "dove" => "MAG-INESISTENTE" }

    parser.resolve_warehouse(row)

    assert_nil row[:_warehouse_id]
    assert_equal "MAG-INESISTENTE", row[:_warehouse_code]
    assert_equal true, row[:_warehouse_new]
  end

  test "FIELD_MAP exposes known header keys" do
    assert_equal :itemcode, ImportParser::FIELD_MAP["item code:"]
    assert_equal :vendita, ImportParser::FIELD_MAP["prezzo showroom"]
    assert_equal :unit_price, ImportParser::FIELD_MAP["prezzo"]
  end

  test "GCODE_KEYS contains the code headers" do
    assert_equal ["Item Code:", "Fabric code:", "var. code:"], ImportParser::GCODE_KEYS
  end
end