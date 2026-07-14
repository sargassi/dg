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

ActiveRecord::Schema[7.2].define(version: 2026_07_14_160921) do
  create_table "abilities", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_abilities_on_name", unique: true
  end

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

  create_table "api_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.boolean "active"
    t.text "token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "archive_categories", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.index ["name"], name: "index_archive_categories_on_name", unique: true
    t.index ["parent_id"], name: "index_archive_categories_on_parent_id"
  end

  create_table "archive_items", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "archive_category_id"
    t.integer "archive_location_id"
    t.string "status", default: "in", null: false
    t.text "notes"
    t.text "qrcode_svg"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "inventory_id"
    t.integer "source_item_id"
    t.index ["archive_category_id"], name: "index_archive_items_on_archive_category_id"
    t.index ["archive_location_id"], name: "index_archive_items_on_archive_location_id"
    t.index ["code"], name: "index_archive_items_on_code", unique: true
    t.index ["inventory_id"], name: "index_archive_items_on_inventory_id"
    t.index ["source_item_id"], name: "index_archive_items_on_source_item_id"
  end

  create_table "archive_locations", force: :cascade do |t|
    t.string "code", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.text "qrcode_svg"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "parent_id"
    t.index ["code"], name: "index_archive_locations_on_code", unique: true
    t.index ["parent_id"], name: "index_archive_locations_on_parent_id"
  end

  create_table "archive_transactions", force: :cascade do |t|
    t.integer "archive_item_id", null: false
    t.string "action", null: false
    t.datetime "date", null: false
    t.integer "operator_id", null: false
    t.string "out_to"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["archive_item_id"], name: "index_archive_transactions_on_archive_item_id"
    t.index ["operator_id"], name: "index_archive_transactions_on_operator_id"
  end

  create_table "areas", force: :cascade do |t|
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "collections", force: :cascade do |t|
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "row_order", default: 0, null: false
  end

  create_table "eticamps", force: :cascade do |t|
    t.string "itemcode"
    t.string "fabricode"
    t.string "varcode"
    t.string "season"
    t.integer "group", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "etichecks", force: :cascade do |t|
    t.string "itemcode"
    t.string "fabricode"
    t.string "varcode"
    t.integer "group", default: 1
    t.string "description"
    t.string "tg"
    t.string "fabric"
    t.integer "qt", default: 1
    t.string "materiale"
    t.string "chi"
    t.string "dove"
    t.string "cspediti"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "etigens", force: :cascade do |t|
    t.string "riga1"
    t.string "riga2"
    t.string "riga3"
    t.string "riga4"
    t.string "riga5"
    t.integer "qty", default: 1
    t.boolean "status", default: false
    t.integer "group"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "dategroup"
    t.integer "pages", default: 1
  end

  create_table "etilabs", force: :cascade do |t|
    t.string "itemcode"
    t.string "fabricode"
    t.string "varcode"
    t.string "description"
    t.string "tg"
    t.string "color"
    t.integer "qty"
    t.string "materiale"
    t.integer "group"
    t.string "customer"
    t.string "supplier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "note"
    t.string "fabric"
    t.string "colfilcuc"
    t.string "lab"
    t.integer "ragg"
  end

  create_table "events", force: :cascade do |t|
    t.string "name"
    t.date "start_time"
    t.date "end_time"
    t.integer "eventype_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recurrent"
    t.text "description"
    t.integer "user_id"
    t.boolean "enabled", default: true, null: false
    t.index ["end_time"], name: "index_events_on_end_time"
    t.index ["eventype_id"], name: "index_events_on_eventype_id"
    t.index ["start_time"], name: "index_events_on_start_time"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "eventypes", force: :cascade do |t|
    t.string "name"
    t.boolean "enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color", default: "#3B82F6"
  end

  create_table "fabriclus", force: :cascade do |t|
    t.string "fab"
    t.string "var"
    t.integer "year"
    t.text "description"
    t.text "note"
    t.text "tg"
    t.text "color"
    t.integer "qty"
    t.string "materiale"
    t.string "customer"
    t.string "supplier"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "mtkg"
    t.decimal "mtkg20"
    t.decimal "mtkgprezzi"
    t.decimal "mtkg20prezzi"
    t.string "perche"
  end

  create_table "inventories", force: :cascade do |t|
    t.integer "qtyavailable"
    t.integer "minstock"
    t.integer "maxstock"
    t.integer "warehouse_id", null: false
    t.integer "location_id"
    t.string "itemcode"
    t.integer "operationtype_id", null: false
    t.integer "itemins_id"
    t.integer "itemouts_id"
    t.boolean "enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "gencode"
    t.integer "item_id"
    t.integer "itemmovement_id"
    t.text "qrcode_svg"
    t.index ["item_id"], name: "index_inventories_on_item_id"
    t.index ["itemins_id"], name: "index_inventories_on_itemins_id"
    t.index ["itemmovement_id"], name: "index_inventories_on_itemmovement_id"
    t.index ["itemouts_id"], name: "index_inventories_on_itemouts_id"
    t.index ["location_id"], name: "index_inventories_on_location_id"
    t.index ["operationtype_id"], name: "index_inventories_on_operationtype_id"
    t.index ["warehouse_id"], name: "index_inventories_on_warehouse_id"
  end

  create_table "itemins", force: :cascade do |t|
    t.date "indate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.integer "operator_id"
    t.string "description"
  end

  create_table "itemins_details", force: :cascade do |t|
    t.integer "itemin_id", null: false
    t.string "itemcode"
    t.integer "qty"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "item_id"
    t.integer "collection_id"
    t.integer "warehouse_id"
    t.integer "location_id"
    t.integer "operationtype_id"
    t.index ["itemin_id"], name: "index_itemins_details_on_itemin_id"
  end

  create_table "itemmovements", force: :cascade do |t|
    t.date "indate"
    t.text "notes"
    t.integer "operator_id"
    t.integer "source_warehouse_id"
    t.integer "source_location_id"
    t.integer "dest_warehouse_id"
    t.integer "dest_location_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "itemmovements_details", force: :cascade do |t|
    t.integer "itemmovement_id", null: false
    t.string "itemcode"
    t.integer "qty"
    t.integer "item_id"
    t.integer "collection_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "warehouse_id"
    t.integer "location_id"
    t.integer "operationtype_id"
    t.index ["itemmovement_id"], name: "index_itemmovements_details_on_itemmovement_id"
  end

  create_table "itemouts", force: :cascade do |t|
    t.date "indate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.integer "operator_id"
  end

  create_table "itemouts_details", force: :cascade do |t|
    t.integer "itemout_id", null: false
    t.string "itemcode"
    t.integer "qty"
    t.integer "item_id"
    t.integer "collection_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "warehouse_id"
    t.integer "location_id"
    t.integer "operationtype_id"
    t.index ["itemout_id"], name: "index_itemouts_details_on_itemout_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "itemcode"
    t.string "fabricode"
    t.string "varcode"
    t.string "description"
    t.string "tg"
    t.text "note"
    t.string "fabric"
    t.string "colour"
    t.decimal "unit_price"
    t.string "materiale"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "gencode"
    t.text "qrcode_svg"
    t.integer "collection_id"
    t.decimal "vendita"
    t.boolean "qr_printed", default: false, null: false
    t.index ["collection_id"], name: "index_items_on_collection_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "code"
    t.integer "warehouse_id", null: false
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "qrcode_svg"
    t.string "gencode"
    t.index ["gencode"], name: "index_locations_on_gencode"
    t.index ["warehouse_id"], name: "index_locations_on_warehouse_id"
  end

  create_table "operationtypes", force: :cascade do |t|
    t.string "code"
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
    t.integer "group"
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

  create_table "proformas", force: :cascade do |t|
    t.text "customer"
    t.date "data_in"
    t.time "data_out"
    t.boolean "closed"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "file"
    t.index ["closed"], name: "index_proformas_on_closed"
  end

  create_table "prows", force: :cascade do |t|
    t.text "code"
    t.integer "proforma_id", null: false
    t.text "description"
    t.text "note"
    t.integer "qty"
    t.text "qr"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "itemcode"
    t.text "fabricode"
    t.text "varcode"
    t.text "tg"
    t.text "color"
    t.text "materiale"
    t.text "origine"
    t.text "doe"
    t.boolean "closed", default: false
    t.integer "identifier"
    t.boolean "done", default: false
    t.time "datedone"
    t.string "colfilcuc"
    t.string "lab"
    t.string "lavaggio"
    t.string "dettagli"
    t.string "ngemelli"
    t.string "totngemelli"
    t.string "colgemelli"
    t.string "fornitore"
    t.string "tempolav"
    t.text "fabric"
    t.index ["closed"], name: "index_prows_on_closed"
    t.index ["proforma_id"], name: "index_prows_on_proforma_id"
  end

  create_table "rassegnas", force: :cascade do |t|
    t.string "titolo"
    t.string "tipologia"
    t.integer "anno"
    t.string "paese"
    t.string "medium"
    t.string "testata"
    t.string "pagine"
    t.text "descrizione"
    t.string "giornalista"
    t.string "photo"
    t.boolean "salva"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "data"
    t.integer "paginea"
    t.string "fotografo"
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

  create_table "stations", force: :cascade do |t|
    t.text "description"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "stock_levels", force: :cascade do |t|
    t.string "gencode", null: false
    t.integer "warehouse_id", null: false
    t.integer "location_id", default: 0, null: false
    t.integer "current_qty", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gencode", "warehouse_id", "location_id"], name: "idx_stock_levels_unique", unique: true
    t.index ["gencode"], name: "index_stock_levels_on_gencode"
    t.index ["warehouse_id"], name: "index_stock_levels_on_warehouse_id"
  end

  create_table "taglia", force: :cascade do |t|
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tempesta", force: :cascade do |t|
    t.integer "prow_id", null: false
    t.boolean "f0", default: true
    t.boolean "f1"
    t.boolean "f2"
    t.boolean "f3"
    t.boolean "f4"
    t.boolean "f5"
    t.date "f1date"
    t.date "f2date"
    t.date "f3date"
    t.date "f4date"
    t.date "f5date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "proforma_id", null: false
    t.integer "user_id", default: 2, null: false
    t.integer "qty", default: 1
    t.string "qrcode"
    t.integer "order", default: 1
    t.index ["proforma_id"], name: "index_tempesta_on_proforma_id"
    t.index ["prow_id"], name: "index_tempesta_on_prow_id"
    t.index ["user_id"], name: "index_tempesta_on_user_id"
  end

  create_table "toolbar_configs", force: :cascade do |t|
    t.string "section", null: false
    t.string "item_label", null: false
    t.boolean "visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "path"
    t.string "icon"
    t.integer "position", default: 0
    t.index ["section", "item_label"], name: "index_toolbar_configs_on_section_and_item_label", unique: true
  end

  create_table "uoms", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_abilities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "ability_id", null: false
    t.integer "granted_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ability_id"], name: "index_user_abilities_on_ability_id"
    t.index ["granted_by_id"], name: "index_user_abilities_on_granted_by_id"
    t.index ["user_id", "ability_id"], name: "index_user_abilities_on_user_id_and_ability_id", unique: true
    t.index ["user_id"], name: "index_user_abilities_on_user_id"
  end

  create_table "user_roles", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "role"], name: "index_user_roles_on_user_id_and_role", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "lastname"
    t.string "user_type", default: "company_operator", null: false
    t.boolean "godlike", default: false, null: false
    t.date "date_of_birth"
    t.date "date_of_hiring"
    t.boolean "enabled", default: true, null: false
    t.string "fiscal_code"
    t.string "vat"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "warehouses", force: :cascade do |t|
    t.string "code"
    t.string "address"
    t.string "city"
    t.string "cap"
    t.string "civic"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "enabled", default: true
    t.text "qrcode_svg"
    t.string "gencode"
    t.index ["gencode"], name: "index_warehouses_on_gencode"
  end

  create_table "zones", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "archive_categories", "archive_categories", column: "parent_id"
  add_foreign_key "archive_items", "archive_categories"
  add_foreign_key "archive_items", "archive_locations"
  add_foreign_key "archive_items", "inventories"
  add_foreign_key "archive_items", "items", column: "source_item_id"
  add_foreign_key "archive_locations", "archive_locations", column: "parent_id"
  add_foreign_key "archive_transactions", "archive_items"
  add_foreign_key "archive_transactions", "users", column: "operator_id"
  add_foreign_key "events", "eventypes"
  add_foreign_key "events", "users"
  add_foreign_key "inventories", "itemins", column: "itemins_id"
  add_foreign_key "inventories", "itemmovements"
  add_foreign_key "inventories", "itemouts", column: "itemouts_id"
  add_foreign_key "inventories", "items"
  add_foreign_key "inventories", "locations"
  add_foreign_key "inventories", "operationtypes"
  add_foreign_key "inventories", "warehouses"
  add_foreign_key "itemins_details", "itemins"
  add_foreign_key "itemmovements_details", "itemmovements"
  add_foreign_key "itemouts_details", "itemouts"
  add_foreign_key "items", "collections"
  add_foreign_key "locations", "warehouses"
  add_foreign_key "prodrow", "areas"
  add_foreign_key "prodrow", "prodcodes"
  add_foreign_key "prows", "proformas"
  add_foreign_key "size_zone_qties", "sizes"
  add_foreign_key "size_zone_qties", "zones"
  add_foreign_key "tempesta", "proformas"
  add_foreign_key "tempesta", "prows"
  add_foreign_key "tempesta", "users"
  add_foreign_key "user_abilities", "abilities"
  add_foreign_key "user_abilities", "users"
  add_foreign_key "user_abilities", "users", column: "granted_by_id"
  add_foreign_key "user_roles", "users"
end
