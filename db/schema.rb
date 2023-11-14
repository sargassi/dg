# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_11_14_105051) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "areas", force: :cascade do |t|
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "prodrow", force: :cascade do |t|
    t.string "prodrow"
    t.integer "prodcode_id", null: false
    t.integer "area_id", null: false
    t.integer "user"
    t.integer "pub", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["area_id"], name: "index_prodrow_on_area_id"
    t.index ["prodcode_id"], name: "index_prodrow_on_prodcode_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "prodcode"
    t.string "itemcode"
    t.string "fabricode"
    t.string "varcode"
    t.string "description"
    t.string "tg"
    t.text "note"
    t.string "fabric"
    t.string "color"
    t.string "materiale"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "qty"
    t.integer "status", default: 0
  end

  create_table "products_imports", force: :cascade do |t|
    t.string "prodcode"
    t.string "itemcode"
    t.string "fabricode"
    t.string "varcode"
    t.text "description"
    t.string "tg"
    t.text "note"
    t.string "fabric"
    t.string "color"
    t.string "materiale"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "size_zone_qties", force: :cascade do |t|
    t.integer "size_id", null: false
    t.integer "zone_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["size_id"], name: "index_size_zone_qties_on_size_id"
    t.index ["zone_id"], name: "index_size_zone_qties_on_zone_id"
  end

  create_table "sizes", force: :cascade do |t|
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "taglia", force: :cascade do |t|
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "zones", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "prodrow", "areas"
  add_foreign_key "prodrow", "prodcodes"
  add_foreign_key "size_zone_qties", "sizes"
  add_foreign_key "size_zone_qties", "zones"
end
