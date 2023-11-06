task :order_job => :environment do
  next if Date.today.wday != 2
  light = LightApi.first
  orders = light.build_orders
  order_parent = []
  puts "______________ORDERS________________________"
  puts orders
  puts "_________________ORDERS______________________"
  orders.each do |x|
    light.create_dashboard_payload(x)
    puts "FINISHED #{x}"
  end
end

task :variant_syncing => :environment do
    # create new variants
    # the order job is very intesive, avoid running all jobs during this time
    next if Date.today.wday == 2 && (3..11).to_a.include?(Time.now.utc.hour)
    total_updated = 0
    l = LightApi.find(3)
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
      l.refresh_token
      new_ls_product = l.create_product(
        name: np['product_title'] + ' ' + np["title"],
        sku: np["sku"],
        upc: np["barcode"],
        cost: np["price"].to_f,
        wholesale_cost: np["cost"].to_f,
        gecko_id: np["id"].to_s
      )
      puts '_____________NEW LS PRODUCT____________________'
      puts new_ls_product
      puts '_____________NEW LS PRODUCT____________________'
      new_product.update(light_id: new_ls_product["Item"]['itemID'])
      sleep 2
    end
    puts '______________NEW PRODUCTS_SYNCED_________________'
    puts not_found.map { |x| x['product_title'] + ' ' + x['title'] }
    puts '______________NEW PRODUCTS_SYNCED_________________'

    variants.each do |var|
      bp = bps.find { |q| q.shopify_variant_id == var['id'].to_s && q.shopify_product_id == var['product_id'].to_s }
      next if bp.nil?
      if bp.cost.to_f != var['cost'].to_f || bp.price.to_f != var['price'].to_f
        l.refresh_token
        updated_product = l.update_ls_product(
          name: var['product_title'] + ' ' + var['title'],
          wholesale_cost: var['cost'].to_f,
          upc: var['barcode'],
          sku: var['sku'],
          price: var['price'].to_f,
          gecko_id: var['id'].to_s,
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

task :process_new_updates => :environment do
  # the order job is very intesive, avoid running all jobs during this time
  next if Date.today.wday == 2 && (3..11).to_a.include?(Time.now.utc.hour)

  s = ShopifyApi.last
  l = LightApi.find(2)
  ProductPayload.where(processed: false).uniq { |f| JSON.parse(f.json_payload)["id"] }.each do |pp|
    params = JSON.parse(pp.json_payload)
    product_id = params["id"]
    variants = params["variants"]
    all_products = BaseProduct.where(shopify_product_id: product_id.to_s)
    # if the product has been updated to archived, destroy all records in the DB and in LS
    if params["status"] == "archived"
      all_products.each do |p|
        l.refresh_token
        deletion = l.delete_product(id: p.light_id)
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
            upc: v["barcode"]
          )
          inventory_item = s.inventory_item(id: v["inventory_item_id"]).dig('inventory_item')
          l.refresh_token
          new_ls_product = l.create_product(
            name: params["title"] + ' ' + v["title"],
            sku: v["sku"],
            upc: v["barcode"],
            cost: v["price"].to_f,
            wholesale_cost: inventory_item["cost"],
            gecko_id: v["id"]
          )
          puts '______________________________'
          puts new_ls_product
          puts '________NEW LS PRODUCT___________'
          new_product.update(light_id: new_ls_product["Item"]["itemID"])
          sleep 2
        else
          # update the inventory item anyway
          inventory_item = s.inventory_item(id: v["inventory_item_id"]).dig('inventory_item')
          puts '______________________________________'
          puts v["price"]
          puts '_______________________________________'
          l.refresh_token
          update = l.update_ls_product(
            id: product.light_id,
            name: params["title"] + ' ' + v["title"],
            sku: v["sku"],
            upc: v["barcode"],
            price: v["price"].to_f,
            wholesale_cost: inventory_item["cost"].to_f,
            gecko_id: v["id"]
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
          deleted_product = l.delete_product(id: dp.light_id)
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

task :automated_sale => :environment do
  # the order job is very intesive, avoid running all jobs during this time
  next if Date.today.wday == 2 && (3..11).to_a.include?(Time.now.utc.hour)

  light = LightApi.find(1)
  light.refresh_token
  recents = light.get_recent_purchase_orders["Order"]
  filtered_orders = recents.select do |o|
    not_completed = o["complete"] == "false"
    custom_fields = o["CustomFieldValues"]
    if !custom_fields.nil?
      ready_for_gecko = custom_fields["CustomFieldValue"].find { |x| x["customFieldID"] == "1" }
      gecko_completed = custom_fields["CustomFieldValue"].find { |x| x["customFieldID"] == "2" }
      ready_for_gecko_bool = ready_for_gecko["value"]
      gecko_completed_bool = gecko_completed["value"]
      ready_for_gecko_bool == "true" && not_completed && gecko_completed_bool == "false"
    else
      false
    end
  end
  puts '________FILT_ORDERS________________'
  puts filtered_orders.length
  puts '___FILT_ORDERS_____________________'
  filtered_orders.each do |x|
    light.refresh_token
    sleep 1
    order = PurchaseOrderJob.find_by(order_id: x["orderID"])
    if order.nil?
      order = PurchaseOrderJob.create(order_id: x['orderID'])
      full_order = light.purchase_order(id: x["orderID"])
      sleep 2
      light.process_to_shopify(id: order.order_id)
    end
  end
  filtered_orders
end

task :testing_job => :environment do
  puts "PLACE HOLDER"
end
