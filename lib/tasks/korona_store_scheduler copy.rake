desc "store orders from korona."
task :store_o => :environment do
  include HTTParty

  if Date.today.wday != 1
    puts "day is not Monday"
    next 
  end
  headers = {
    'Content-Type': 'application/json',
    'X-Shopify-Access-Token': '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'
  }
  koronaAccountId = "bb26d9a6-3cdd-4c90-bc1c-384387f39783"
  user = 'admin'
  password = "password"
  korona_headers = {
    'Authorization': "Basic #{Base64::encode64("#{user}:#{password}")}",
    "Content-Type": "application/json"
  }
  # store_product_id = []
  shopify_product = []
  # base_product = BaseProduct.all
  s = ShopifyApi.last
  shopify_products = s.products
  # shopify_products[0]["variants"][0]["sku"]
  shopify_products.each do |sp|
    sp["variants"].each do |spv|
      shopify_product << spv
    end
  end
  # this will help us get store order id
  get_store_order = self.class.get("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders", headers: korona_headers).parsed_response
  # if store is empty then it might throw error
    get_store_order["results"].each do |order|
      storeOrderId = order["id"]
      # this to get store order items.
      get_store_order_items = self.class.get("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items", headers: korona_headers).parsed_response
      get_store_order_items["results"].each do |item|
        # store_product_id << item["product"]["id"]
        productId = item["product"]["id"]

        get_store_product_code = self.class.get("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/products/#{productId}", headers: korona_headers).parsed_response
        get_store_product_code["codes"].each do |p_code|
          product_code = p_code["productCode"]
          # loop on shopify_product to match the product code
          # product_confirm = (base_product.where(sku: product_code)).exists?
          s_product = shopify_product.select{|p| p["sku"] == product_code}.last

          # product_confirm = shopify_product[].include? product_code
          if !(s_product.nil?)
            # now I have to check the quantity for the selected shopify product.
            # if base_product.quantity==0
            # if !(s_product["inventory_quantity"] < 0)
            if !(s_product.find{|p| p["inventory_quantity"] == 0}.nil?)
              # now just delete the product from korona if true.
              d = self.class.delete("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items/#{productId}", headers: korona_headers).parsed_response
              puts "deleted #{d}"
            else
              puts "product is available in warehouse"
              # booked
            end
          else
            puts "product not found"
            d = self.class.delete("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items/#{productId}", headers: korona_headers).parsed_response
            puts "deleted #{d}"
          end
        end
      end
    end
end
