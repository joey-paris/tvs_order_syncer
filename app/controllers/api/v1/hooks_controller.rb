class Api::V1::HooksController < ApplicationController

  def shopify_product_create_hook
    if params[:status] != "draft"
      ProductPayload.create(json_payload: params.to_json, korona_flag: true)
    end
    head :ok
  end

  def shopify_product_update_hook
    if params[:status] != "draft"
      # UpdatePayload.create(json_payload: params.to_json)
    end
    head :ok
  end
end


# CREATE HOOK SCHEMA
# { "id"=>6842075938868, "title"=>"[DEV] TEST PRODUCT", "body_html"=>"", "vendor"=>"sdinland10", "product_type"=>"",
#   "created_at"=>"2022-06-21T04:12:26-04:00", "handle"=>"dev-test-product", "updated_at"=>"2022-06-21T04:12:28-04:00",
#   "published_at"=>nil, "template_suffix"=>"", "status"=>"draft", "published_scope"=>"web", "tags"=>"", "admin_graphql_api_id"=>"gid://shopify/Product/6842075938868",
#   "variants"=>[
#     {"id"=>40338604163124,
#       "product_id"=>6842075938868,
#       "title"=>"Default Title",
#       "price"=>"12.99",
#       "sku"=>"MDTVSTEST",
#       "position"=>1,
#       "inventory_policy"=>"deny",
#       "compare_at_price"=>nil,
#       "fulfillment_service"=>"manual",
#       "inventory_management"=>"shopify",
#       "option1"=>"Default Title",
#       "option2"=>nil, "option3"=>nil,
#       "created_at"=>"2022-06-21T04:12:27-04:00",
#       "updated_at"=>"2022-06-21T04:12:27-04:00",
#       "taxable"=>true, "barcode"=>"111222333444",
#       "grams"=>0,
#       "image_id"=>nil,
#       "weight"=>0.0,
#       "weight_unit"=>"lb",
#       "inventory_item_id"=>42433273397300,
#       "inventory_quantity"=>0,
#       "old_inventory_quantity"=>0,
#       "requires_shipping"=>true,
#       "admin_graphql_api_id"=>"gid://shopify/ProductVariant/40338604163124"}
#     ], "options"=>[{"id"=>8774794477620, "product_id"=>6842075938868, "name"=>"Title", "position"=>1, "values"=>["Default Title"]}], "images"=>[], "image"=>nil, "format"=>:json, "controller"=>"api/v1/hooks", "action"=>"shopify_product_create_hook", "hook"=>{"id"=>6842075938868, "title"=>"[DEV] TEST PRODUCT", "body_html"=>"", "vendor"=>"sdinland10", "product_type"=>"", "created_at"=>"2022-06-21T04:12:26-04:00", "handle"=>"dev-test-product", "updated_at"=>"2022-06-21T04:12:28-04:00", "published_at"=>nil, "template_suffix"=>"", "status"=>"draft", "published_scope"=>"web", "tags"=>"", "admin_graphql_api_id"=>"gid://shopify/Product/6842075938868", "variants"=>[{"id"=>40338604163124, "product_id"=>6842075938868, "title"=>"Default Title", "price"=>"12.99", "sku"=>"MDTVSTEST", "position"=>1, "inventory_policy"=>"deny", "compare_at_price"=>nil, "fulfillment_service"=>"manual", "inventory_management"=>"shopify", "option1"=>"Default Title", "option2"=>nil, "option3"=>nil, "created_at"=>"2022-06-21T04:12:27-04:00", "updated_at"=>"2022-06-21T04:12:27-04:00", "taxable"=>true, "barcode"=>"111222333444", "grams"=>0, "image_id"=>nil, "weight"=>0.0, "weight_unit"=>"lb", "inventory_item_id"=>42433273397300, "inventory_quantity"=>0, "old_inventory_quantity"=>0, "requires_shipping"=>true, "admin_graphql_api_id"=>"gid://shopify/ProductVariant/40338604163124"}], "options"=>[{"id"=>8774794477620, "product_id"=>6842075938868, "name"=>"Title", "position"=>1, "values"=>["Default Title"]}], "images"=>[], "image"=>nil}
#   }
