# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2023_08_04_110242) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "base_products", force: :cascade do |t|
    t.string "light_id"
    t.string "shopify_variant_id"
    t.string "shopify_product_id"
    t.string "upc"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "sku"
    t.string "cost"
    t.string "price"
    t.boolean "korona_flag", default: false
    t.index ["light_id"], name: "index_base_products_on_light_id"
    t.index ["shopify_product_id"], name: "index_base_products_on_shopify_product_id"
    t.index ["shopify_variant_id"], name: "index_base_products_on_shopify_variant_id"
    t.index ["upc"], name: "index_base_products_on_upc"
  end

  create_table "light_apis", force: :cascade do |t|
    t.string "client_id"
    t.string "client_secret"
    t.string "refresh"
    t.string "account"
    t.string "light_key"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "order_line_items", force: :cascade do |t|
    t.bigint "base_product_id"
    t.string "shop_id", null: false
    t.string "order_id", null: false
    t.string "quantity", null: false
    t.string "order_line_item_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["base_product_id"], name: "index_order_line_items_on_base_product_id"
  end

  create_table "product_payloads", force: :cascade do |t|
    t.boolean "processed", default: false
    t.jsonb "json_payload"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "korona_flag", default: false
  end

  create_table "purchase_order_jobs", force: :cascade do |t|
    t.string "order_id"
    t.boolean "completed", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "shopify_apis", force: :cascade do |t|
    t.string "client_id"
    t.string "client_secret"
    t.string "auth_key"
    t.string "refresh"
    t.string "account"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "shopify_sales_orders", force: :cascade do |t|
    t.jsonb "sale_order", null: false
    t.string "purchase_order_id", null: false
    t.string "sales_order_id", null: false
    t.boolean "completed", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "update_payloads", force: :cascade do |t|
    t.jsonb "json_payload"
    t.boolean "processed", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  add_foreign_key "order_line_items", "base_products"
end
