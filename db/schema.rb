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

ActiveRecord::Schema[8.1].define(version: 2026_02_16_065828) do
  create_table "accounts", force: :cascade do |t|
    t.string "category", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.boolean "is_lock", default: false, null: false
    t.string "name", null: false
    t.string "parent_code"
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_accounts_on_category"
    t.index ["code"], name: "index_accounts_on_code", unique: true
    t.index ["parent_code"], name: "index_accounts_on_parent_code"
  end

  create_table "bank_import_settings", force: :cascade do |t|
    t.string "bank_account_code", null: false
    t.datetime "created_at", null: false
    t.string "date_column", null: false
    t.string "deposit_column", null: false
    t.string "deposit_counter_code", null: false
    t.string "description_column", null: false
    t.boolean "has_header", default: true, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.string "withdrawal_column", null: false
    t.string "withdrawal_counter_code", null: false
    t.index ["name"], name: "index_bank_import_settings_on_name", unique: true
  end

  create_table "import_rules", force: :cascade do |t|
    t.string "account_code", null: false
    t.datetime "created_at", null: false
    t.string "direction", default: "both", null: false
    t.string "keyword", null: false
    t.string "match_type", default: "contains", null: false
    t.integer "priority", default: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["keyword", "direction"], name: "index_import_rules_on_keyword_and_direction"
    t.index ["priority"], name: "index_import_rules_on_priority"
  end

  create_table "voucher_lines", force: :cascade do |t|
    t.string "account", null: false
    t.string "account_code", default: "", null: false
    t.datetime "created_at", null: false
    t.decimal "credit_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "debit_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.string "note"
    t.datetime "updated_at", null: false
    t.integer "voucher_id", null: false
    t.index ["account_code"], name: "index_voucher_lines_on_account_code"
    t.index ["voucher_id"], name: "index_voucher_lines_on_voucher_id"
  end

  create_table "vouchers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.date "recorded_on", null: false
    t.datetime "updated_at", null: false
    t.string "voucher_number", null: false
    t.index ["voucher_number"], name: "index_vouchers_on_voucher_number", unique: true
  end

  add_foreign_key "accounts", "accounts", column: "parent_code", primary_key: "code"
  add_foreign_key "voucher_lines", "vouchers"
end
