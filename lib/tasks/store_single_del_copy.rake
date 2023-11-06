require_relative "korona_helper"
include KoronaHelper
desc "syncing store orders of korona."
task :syncing_korona_po => :environment do
  if Date.today.wday != 2
    # next
  end
  product_payload_variants = []
  matched_korona_product = []
  p_payload = ProductPayload.all
  p_payload.each do |p|
    pload = JSON.parse(p["json_payload"])
    pload["variants"].each do |v|
      product_payload_variants << v
    end
  end
  koronaAccountId = "bb26d9a6-3cdd-4c90-bc1c-384387f39783"
  get_all_korona_products = []
  get_korona_products = apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/products")
  get_all_korona_products << get_korona_products["results"]
  if !get_all_korona_products.nil? 
    store_total_page = get_korona_products["pagesTotal"]
    store_current_page = get_korona_products["currentPage"]
    while store_total_page >= store_current_page
      if !(store_current_page == 1)
        get_korona_products = apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/products?page=#{store_current_page}")
        get_all_korona_products << get_korona_products["results"]
      end
      store_current_page = store_current_page + 1
    end
  end
  get_store_order = apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders")
  if !get_store_order.nil? 
    new_store_count = 0
    get_store_order["results"].each do |order|
      if !order["finishTime"].nil?
        puts "store with id: #{order["id"]} is already finished."
        next
      end
      new_store_count = new_store_count + 1
      storeOrderId = order["id"]
      # if new_store_count == 2
      #   byebug
      # end
      # here I should initialize order_list and payload because here new store gets in.
      order_list=[]
      payload = {}
      get_store_order_items_collection = []
      store_order_warehouse_name = order["targetOrganizationalUnit"]["name"]
      store_organizational_id = order["targetOrganizationalUnit"]["id"]
      get_store_order_items = apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items")
      get_store_order_items_collection << get_store_order_items
      store_total_page = get_store_order_items["pagesTotal"]
      store_current_page = get_store_order_items["currentPage"]
      # while store_total_page != (store_current_page-1)
      while store_total_page >= store_current_page
        if !(store_current_page == 1)
          get_store_order_items_collection << apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items?page=#{store_current_page}")
        end
        store_current_page = store_current_page + 1
      end
      get_store_order_items_collection.each do |get_store_order_items|
        if !get_store_order_items.nil? 
          get_store_order_items["results"].each do |item|
            productId = item["product"]["id"]
            # get all products from korona and compare it at once.
            get_all_korona_products.each do |p_part|
              matched_korona_product = p_part.select{|x| x["id"] == productId}
              # if matched_korona_product is not nil then continue and break the loop otherwise go to next iteration
              if !matched_korona_product.empty?
                if matched_korona_product.count > 1
                  puts "More than one product found in korona with product id: #{productId}"
                end
                # puts "breaking loop"
                break
              else
                # puts "going to next loop"
                next
              end
            end
            if !matched_korona_product.empty?
              matched_korona_product.each do |m_product|
                if !m_product["codes"].nil?
                  m_product["supplierPrices"].each do |code|
                    # byebug
                    order_code = code["orderCode"]
                    product_payload_variant = product_payload_variants.select{ |p| p["sku"] == order_code }
                    if product_payload_variant.any?
                      if product_payload_variant.any? { |p| p["inventory_quantity"] == 0 }
                        d = apiDel("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items/#{productId}")
                        puts "quantity is zero deleted #{d}"
                      else
                        puts "product is available in warehouse"
                        k_product_stock = apiGet("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/products/#{productId}/stocks")
                        # k_product_stock["results"][0]["amount"]["actual"]
                        order_list << {
                          "product_name": item["product"]["name"],
                          "product_id": item["product"]["id"],
                          "po_quantity": item["quantity"],
                          "product_price": m_product["prices"][0]["value"],
                          # "product_price": product_payload_variant.first["price"],
                          "shopify_varient_id": (product_payload_variant.first["id"]),
                          # "shopify_varient_id": (product_payload_variant.first["admin_graphql_api_id"]).match(/\d+$/)[0],
                          "product_sku": product_payload_variant.first["sku"],
                          "warehouse_quantity": product_payload_variant.first["inventory_quantity"],
                          # "korona_quantity": m_product["subproducts"]? m_product["subproducts"][0]["quantity"] : 0
                          "korona_quantity": k_product_stock["results"]? k_product_stock["results"][0]["amount"]["actual"] : 0
                        }
                      end
                    else
                      puts "product not found"
                      d = apiDel("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items/#{productId}")
                      puts "deleted #{d}"
                    end    
                  end
                else
                  puts "product with id: #{productId} has no sku or product code. So, cannot be matched with warehouse products."
                  d = apiDel("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items/#{productId}")
                  puts "deleted #{d}"
                end
              end
              if order_list.empty?
                puts "no product found in order list"
                next
              end
              payload = {
                "store_order_id": storeOrderId,
                "store_name": "#{store_order_warehouse_name}: #{Date.today.to_s}",
                "order_items": order_list,
                "organizational_id": store_organizational_id,
                "group_name": "Week of #{Date.today.to_s}"
              }
            else
              puts "product with id: #{productId} has no sku or product code. So, cannot be matched with warehouse products."
              d = apiDel("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/storeOrders/#{storeOrderId}/items/#{productId}")
              puts "deleted #{d}"
            end
          end
        else
          puts "No items in the store, add them first"
        end
      end
      if order_list.empty?
        puts "no product is in stock or matched in this store order PO"
        next
      end
      # apiPost("https://tvs-stores-po-app.herokuapp.com/hooks/korona_order_create_hook", JSON.dump(payload))
      apiPost("http://localhost:3000/hooks/korona_order_create_hook", JSON.dump(payload)) if !payload.empty?
    end
    # send all product of korona to get sku, and all products from shopify to compare quantity with it.
    new_product_payload = {
      "product_payload_variants": product_payload_variants,
      "get_all_korona_products": get_all_korona_products
    }
    # apiPost("https://tvs-stores-po-app.herokuapp.com/hooks/korona_new_product_check_hook", JSON.dump(payload))
    apiPost("http://localhost:3000/hooks/korona_new_product_check_hook", JSON.dump(new_product_payload))
  else
    puts "There are no stores, create it first."
  end
end

task :korona_variants_syncing => :environment do
  # next if Date.today.wday == 2 && (3..11).to_a.include?(Time.now.utc.hour)
  total_updated = 0
  s = ShopifyApi.last
  variants = s.gen_product_payload
  bps = BaseProduct.where(shopify_variant_id: variants.pluck("id"))
  not_found = variants.select do |v|
    bp = bps.find { |q| q.shopify_variant_id == v['id'].to_s && q.shopify_product_id == v['product_id'].to_s }
    bp.nil?
  end
  puts '__________New Variants Needing Syncing___________'
  puts not_found.length
  puts '__________New Variants Needing Syncing___________'
  not_found.each do |np|
    new_product = BaseProduct.create(
      shopify_variant_id: np['id'].to_s,
      shopify_product_id: np['product_id'].to_s,
      upc: np['barcode'],
      sku: np['sku'],
      cost: np['cost'],
      price: np['price']
    )
    new_ls_product = create_k_product(
      name: np['product_title'] + ' ' + np["title"],
      sku: np["sku"],
      upc: np["barcode"],
      price: np["price"].to_f,
      wholesale_cost: np["cost"].to_f,
      shopify_variant_id: np["id"].to_s
    )
    puts '_____________NEW LS PRODUCT____________________'
    puts new_ls_product
    puts '_____________NEW LS PRODUCT____________________'
    new_product.update(light_id: new_ls_product[0]['id'], korona_flag: true)
    sleep 2
  end
  puts '______________NEW PRODUCTS_SYNCED_________________'
  puts not_found.map { |x| x['product_title'] + ' ' + x['title'] }
  puts '______________NEW PRODUCTS_SYNCED_________________'

  variants.each do |var|
    bp = bps.find { |q| q.shopify_variant_id == var['id'].to_s && q.shopify_product_id == var['product_id'].to_s }
    next if bp.nil?
    if bp.cost.to_f != var['cost'].to_f || bp.price.to_f != var['price'].to_f
      updated_product = update_k_product(
        name: var['product_title'] + ' ' + var['title'],
        wholesale_cost: var['cost'].to_f,
        upc: var['barcode'],
        sku: var['sku'],
        price: var['price'].to_f,
        shopify_variant_id: var['id'].to_s,
        id: bp.light_id
      )
      puts '____________UPDATE____________________'
      puts updated_product
      puts '____________UPDATE______________________'
      updated_bp = bp.update(cost: var['cost'], price: var['price'], upc: var['barcode'], sku: var['sku'])
      total_updated += 1
      sleep 3
    end
  end
  puts '___________TOTAL UPDATED PRODUCTS____________________'
  puts total_updated
  puts '____________TOTAL UPDATED PRODUCTS______________________'
end

task :process_new_korona_updates => :environment do
  # next if Date.today.wday == 2 && (3..11).to_a.include?(Time.now.utc.hour
  s = ShopifyApi.last
  ProductPayload.where(processed: false).uniq { |f| JSON.parse(f.json_payload)["id"] }.each do |pp|
    params = JSON.parse(pp.json_payload)
    product_id = params["id"]
    variants = params["variants"]
    all_products = BaseProduct.where(shopify_product_id: product_id.to_s)
    # if the product has been updated to archived, destroy all records in the DB and in LS
    if params["status"] == "archived"
      all_products.each do |p|
        deletion = delete_k_product(id: p.light_id)
        puts '__________ARCHIVED PRODUCT_____________'
        puts deletion
        puts '__________ARCHIVED PRODUCT_____________'
        base_destroy = p.destroy
        puts '_________BASE_____________'
        puts base_destroy
        puts '_______BASE_______________'
      end
    else
      # create variants if not there
      variants.each do |v|
        product = all_products.find_by(shopify_variant_id: v["id"].to_s)
        # if there is a new variant, create the variant
        if product.nil?
          new_product = BaseProduct.new(
            shopify_product_id: product_id,
            shopify_variant_id: v["id"].to_s,
            sku: v["sku"],
            upc: v["barcode"],
            cost: v['cost'],
            price: v['price']
          )
          inventory_item = s.inventory_item(id: v["inventory_item_id"]).dig('inventory_item')
          new_ls_product = create_k_product(
            name: params["title"] + ' ' + v["title"],
            sku: v["sku"],
            upc: v["barcode"],
            price: v["price"].to_f,
            wholesale_cost: inventory_item["cost"],
            shopify_variant_id: v["id"]
          )
          puts '______________________________'
          puts new_ls_product
          puts '________NEW LS PRODUCT___________'
          new_product.update(light_id: new_ls_product[0]["id"])
          sleep 2
        else
          # update the inventory item anyway
          inventory_item = s.inventory_item(id: v["inventory_item_id"]).dig('inventory_item')
          puts '______________________________________'
          puts v["price"]
          puts '_______________________________________'
          update = update_k_product(
            id: product.light_id,
            name: params["title"] + ' ' + v["title"],
            sku: v["sku"],
            upc: v["barcode"],
            price: v["price"].to_f,
            wholesale_cost: inventory_item["cost"].to_f,
            shopify_variant_id: v["id"]
          )
          product.update(
            sku: v["sku"],
            upc: v["barcode"]
          )
          puts '______________________________'
          puts update
          puts '________UPDATED LS PRODUCT___________'
          sleep 2
        end
      end
      # delete products if there are more in the DB than there are being pulled down
      if all_products.length > variants.length
        v_ids = variants.pluck("id").map(&:to_s)
        deleted_products = all_products.select { |q| !v_ids.include?(q.shopify_variant_id) }
        deleted_products.each do |dp|
          deleted_product = delete_k_product(id: dp.light_id)
          dp.destroy
          puts '______________________________'
          puts deleted_product
          puts '________DELETED LS PRODUCT___________'
          sleep 2
        end
      end
    end
  end
  ProductPayload.update_all(processed: true)
end

task :test_hook => :environment do
  shopify_api = ShopifyApi.last
  # byebug
  shopify_api.hooks
end
