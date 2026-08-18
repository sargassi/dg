require "test_helper"

class ImportValidatorTest < ActiveSupport::TestCase
  def row(index, item_code:, collection_desc: nil, collection_id: nil, collection_new: false, fabric_code: "FAB", var_code: "01")
    {
      :_index => index,
      ImportParser::ITEM_CODE_KEY => item_code,
      ImportParser::FABRIC_CODE_KEY => fabric_code,
      ImportParser::VAR_CODE_KEY => var_code,
      :_collection_id => collection_id,
      :_collection_description => collection_desc,
      :_collection_new => collection_new
    }
  end

  test "validation_details flags missing item code and missing collection" do
    data = { rows: [row(2, item_code: "", collection_desc: nil)] }

    details = ImportValidator.new.validation_details(data)

    assert_includes details[2][ImportParser::ITEM_CODE_KEY], "manca il codice articolo"
    assert_includes details[2][ImportParser::NOTE_KEY], "manca la collezione"
  end

  test "validation_details flags duplicate gencodes" do
    data = {
      rows: [
        row(2, item_code: "ABC", collection_desc: "P"),
        row(3, item_code: "ABC", collection_desc: "P")
      ]
    }

    details = ImportValidator.new.validation_details(data)

    assert_includes details[2][:gencode], "gencode duplicato"
    assert_includes details[3][:gencode], "gencode duplicato"
  end

  test "validate_rows formats messages as Riga indexed strings" do
    data = { rows: [row(5, item_code: "", collection_desc: nil)] }

    messages = ImportValidator.new.validate_rows(data)

    assert_equal ["Riga 5: manca il codice articolo", "Riga 5: manca la collezione"], messages
  end

  test "classify_rows returns :update for existing gencode and :new otherwise" do
    existing = Item.create!(
      itemcode: "C1",
      fabricode: "F1",
      varcode: "V1",
      collection: collections(:one)
    )

    data = {
      rows: [
        row(2, item_code: "C1", collection_id: existing.collection_id, fabric_code: "F1", var_code: "V1"),
        row(3, item_code: "C2", collection_id: existing.collection_id, fabric_code: "F1", var_code: "V1"),
        row(4, item_code: "C3", collection_desc: "Collezione Nuova")
      ]
    }

    classes = ImportValidator.new.classify_rows(data)

    assert_equal :update, classes[2]
    assert_equal :new, classes[3]
    assert_equal :new, classes[4]
  end

  test "summarize counts new and updated items and collects new collections" do
    existing = Item.create!(
      itemcode: "S1",
      fabricode: "SF1",
      varcode: "SV1",
      collection: collections(:one)
    )
    existing_desc = existing.collection.description

    data = {
      rows: [
        row(2, item_code: "S1", collection_id: existing.collection_id, collection_desc: existing_desc, fabric_code: "SF1", var_code: "SV1"),
        row(3, item_code: "N1", collection_desc: "Nuova Collezione A", collection_new: true),
        row(4, item_code: "N2", collection_desc: "Nuova Collezione A", collection_new: true)
      ]
    }

    summary = ImportValidator.new.summarize(data)

    assert_equal 3, summary[:total]
    assert_equal 2, summary[:new_items]
    assert_equal 1, summary[:updated_items]
    assert_equal ["Nuova Collezione A"], summary[:new_collections]
    assert_includes summary[:existing_collections], existing_desc
  end

  test "summarize deduplicates collections" do
    data = {
      rows: [
        row(2, item_code: "N1", collection_desc: "Unica", collection_new: true),
        row(3, item_code: "N2", collection_desc: "Unica", collection_new: true)
      ]
    }

    summary = ImportValidator.new.summarize(data)

    assert_equal ["Unica"], summary[:new_collections]
    assert_equal 0, summary[:existing_collections].size
  end
end