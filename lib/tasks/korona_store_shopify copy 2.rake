require_relative "korona_helper"
desc "syncing store orders of korona."
task :syncing_korona => :environment do
include KoronaHelper
  shopify_product = []
  s = ShopifyApi.last
  shopify_products = s.products
  shopify_products.each do |sp|
    sp["variants"].each do |spv|
      shopify_product << spv
    end
  end
  koronaAccountId = "bb26d9a6-3cdd-4c90-bc1c-384387f39783"
  get_store_order = apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders")
  if !get_store_order.nil? 
    get_store_order["results"].each do |order|
      storeOrderId = order["id"]
      get_store_order_items = apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items")
      if !get_store_order_items.nil? 
      get_store_order_items["results"].each do |item|
        productId = item["product"]["id"]
        get_store_product_code = apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/products/#{productId}")
        get_store_product_code["codes"].each do |p_code|
          product_code = p_code["productCode"]
          s_product = shopify_product.select{|p| p["sku"] == product_code}
          if !(s_product.empty?)
            if s_product.any? { |p| p["inventory_quantity"] == 0 }
              d = apiDel("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items/#{productId}")
              puts "quantity is zero deleted #{d}"
            else
              puts "product is available in warehouse"
            end
          else
            puts "product not found"
            d = apiDel("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items/#{productId}")
            puts "deleted #{d}"
          end
        end
      end
      else
        puts "No items in the store, add them first"
      end
    end
  else
    puts "There are no stores, create it first."
  end
end
