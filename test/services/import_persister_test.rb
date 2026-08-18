require "test_helper"

class ImportPersisterTest < ActiveSupport::TestCase
  def row(index, item_code:, price: nil, collection_id: nil, note: nil)
    {
      :_index => index,
      :_collection_id => collection_id,
      :_collection_description => note,
      :_collection_new => false,
      ImportParser::ITEM_CODE_KEY => item_code,
      ImportParser::FABRIC_CODE_KEY => "FAB",
      ImportParser::VAR_CODE_KEY => "01",
      ImportParser::PREZZO_KEY => price,
      "Description:" => "Descrizione"
    }
  end

  test "save creates a new item and records the id" do
    collection = collections(:one)
    data = { rows: [row(2, item_code: "ABC", price: 10, collection_id: collection.id)] }

    stats = ImportPersister.new.save(data)

    assert_equal 1, stats[:created]
    assert_equal 0, stats[:updated]
    assert_empty stats[:errors]
    assert_equal 1, stats[:created_ids].size

    item = Item.find(stats[:created_ids].first)
    assert_equal "ABCFAB01_#{collection.id}", item.gencode
    assert_equal collection.id, item.collection_id
  end

  test "save rounds prices to two decimals instead of truncating" do
    collection = collections(:one)
    data = { rows: [row(2, item_code: "P1", price: 80.5, collection_id: collection.id)] }

    stats = ImportPersister.new.save(data)

    item = Item.find(stats[:created_ids].first)
    assert_equal 80.5, item.unit_price
  end

  test "save handles decimal prices written with a comma" do
    collection = collections(:one)
    data = { rows: [row(2, item_code: "P2", price: "12,34", collection_id: collection.id)] }

    stats = ImportPersister.new.save(data)

    item = Item.find(stats[:created_ids].first)
    assert_equal 12.34, item.unit_price
  end

  test "save captures non-numeric prices as row errors and skips the item" do
    collection = collections(:one)
    data = { rows: [row(2, item_code: "P3", price: "N/A", collection_id: collection.id)] }

    stats = ImportPersister.new.save(data)

    assert_equal 0, stats[:created]
    assert_equal 1, stats[:errors].size
    assert_match(/prezzo non valido/, stats[:errors].first[:error])
    assert_nil Item.find_by(itemcode: "P3")
  end

  test "save rejects negative prices" do
    collection = collections(:one)
    data = { rows: [row(2, item_code: "P4", price: -5, collection_id: collection.id)] }

    stats = ImportPersister.new.save(data)

    assert_equal 0, stats[:created]
    assert_equal 1, stats[:errors].size
    assert_nil Item.find_by(itemcode: "P4")
  end

  test "save updates an existing item with the same gencode" do
    existing = Item.create!(
      itemcode: "UP1",
      fabricode: "FAB",
      varcode: "01",
      collection: collections(:one)
    )
    data = {
      rows: [{
        :_index => 2,
        :_collection_id => existing.collection_id,
        :_collection_description => nil,
        :_collection_new => false,
        ImportParser::ITEM_CODE_KEY => "UP1",
        ImportParser::FABRIC_CODE_KEY => "FAB",
        ImportParser::VAR_CODE_KEY => "01",
        ImportParser::PREZZO_KEY => 25.5,
        "Description:" => "Aggiornata"
      }]
    }

    stats = ImportPersister.new.save(data)

    assert_equal 1, stats[:updated]
    assert_equal [existing.id], stats[:updated_ids]
    existing.reload
    assert_equal 25.5, existing.unit_price
    assert_equal "Aggiornata", existing.description
  end

  test "save yields progress with done and total" do
    collection = collections(:one)
    data = {
      rows: [
        row(2, item_code: "PR1", collection_id: collection.id),
        row(3, item_code: "PR2", collection_id: collection.id)
      ]
    }

    progress = []
    ImportPersister.new.save(data) { |done, total| progress << [done, total] }

    assert_equal [[1, 2], [2, 2]], progress
  end

  test "save regenerates the qr code via the model callback" do
    collection = collections(:one)
    data = { rows: [row(2, item_code: "QR1", collection_id: collection.id)] }

    stats = ImportPersister.new.save(data)

    item = Item.find(stats[:created_ids].first)
    assert item.qrcode_svg.present?
    assert_match(/<svg/, item.qrcode_svg)
  end

  test "ensure_dependencies! creates new collections and sets their ids" do
    data = {
      rows: [
        { :_collection_new => true, :_collection_description => "Collezione Da Creare", :_collection_id => nil },
        { :_collection_new => true, :_collection_description => "Collezione Da Creare", :_collection_id => nil }
      ]
    }

    ImportPersister.new.ensure_dependencies!(data)

    collection = Collection.find_by(description: "COLLEZIONE DA CREARE")
    assert_not_nil collection
    data[:rows].each do |r|
      assert_equal collection.id, r[:_collection_id]
      assert_equal false, r[:_collection_new]
    end
  end

  test "ensure_dependencies! leaves existing collections untouched" do
    collection = collections(:one)
    data = {
      rows: [
        { :_collection_new => false, :_collection_description => collection.description, :_collection_id => collection.id }
      ]
    }

    assert_no_difference "Collection.count" do
      ImportPersister.new.ensure_dependencies!(data)
    end
  end

  test "rollback destroys only the created ids" do
    kept = Item.create!(itemcode: "KEEP", fabricode: "F", varcode: "V", collection: collections(:one))
    victim = Item.create!(itemcode: "DEL", fabricode: "F", varcode: "V", collection: collections(:one))

    ImportPersister.new.rollback(created_ids: [victim.id])

    assert_nil Item.find_by(id: victim.id)
    assert_not_nil Item.find_by(id: kept.id)
  end
end