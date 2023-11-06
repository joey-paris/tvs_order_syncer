namespace :seed do

  # BEGIN USED SCRIPTS
  task :rerun_order_job => :environment do
    # when the weekly job fails, you can alter the filtering of what shops to generate
    # orders for on light_api.rb (I will denote with **). Then you can run this job
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

  task :push_to_dashboard => :environment do
    l = LightApi.first
    # Add the IDs of orders did that didnt process to the dashboard
    # orders = [2260, 2259]
    orders = [2196, 2197, 2198, 2199, 2200, 2201, 2002, 2203, 2204]
    orders.each do |o|
      sleep 4
      l.refresh_token
      order = l.purchase_order(id: o.to_s)
      l.create_dashboard_payload(order)
    end
    # orders = l.build_orders(["7", "8", "9", "16"])
    # binding.pry
  end

  task :generate_token => :environment do
    # https://cloud.lightspeedapp.com/oauth/authorize.php?response_type=code&client_id=bbe3e974cedb7170e6197317cdbdde61715202c31ead8818cd5f65e8261efdfa&scope=employee:all
    # add client id, enter in browser with session active on LS account, and paste code into auth var
    # in pry update with the needed credentials.
    # when refreshing token, it will update automatically
    # {"access_token"=>"f2cc0454259ebb10a3ca85866fc0ec9bdb0d3ac1", "expires_in"=>326, "token_type"=>"bearer", "scope"=>"employee:all", "refresh_token"=>"bd9089110b144bf2f1bfd0592aa345cc1eea07ee"}
    #    {"access_token"=>"37dd710765077812ae7c579e4b493f56dba2b3d0",
    #    "expires_in"=>"1800",
    #    "token_type"=>"bearer",
    #    "scope"=>"employee:all systemuserid:947084",
    #    "refresh_token"=>"9fb70dd890071cb799bd3811eaeba3315119f6eb"}
    light = LightApi.new(
      client_id: "bbe3e974cedb7170e6197317cdbdde61715202c31ead8818cd5f65e8261efdfa",
      client_secret: "d5d7597124cbe2feb44ba730a0d96745ef8ae06f65b241dd37d29794dbd86e26",
      refresh: '9fb70dd890071cb799bd3811eaeba3315119f6eb',
      light_key: '37dd710765077812ae7c579e4b493f56dba2b3d0',
      account: '240034'
    )
    light.save!
    auth = light.authorize(code: "753f684c3991e9cce58e4bed957a19db866bd98f")
    binding.pry
    # https://boiling-brook-31294.herokuapp.com/?code=30842e0dc00088d1a126f9fadcfb465a66925fe3
  end

  # END USED SCRIPTS

  # BEGIN OLD SCRIPTS

  task :updating_prods => :environment do
    file = JSON.parse(File.read('lib/tasks/updating_products.json'))
    headers = ['Name', 'Shopify Variant ID', 'Shopify Price', 'Shopify Cost', 'Light Cost', 'Light Price']
    data = CSV.generate(headers: true) do |csv|
      csv << headers
      file.each do |l|
        arr = [
          l['product_title'] + ' ' + l['title'],
          l['id'].to_s,
          l['price'],
          l['cost'],
          l['light_cost'],
          l['light_price']
        ]
        csv << arr
      end
    end
    File.write("update_job.csv", data)
  end

  task :run_update_check => :environment do
    s = ShopifyApi.new(
      auth_key: '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'
    )
    l = LightApi.first
    variants = s.gen_product_payload
    bps = BaseProduct.where(shopify_variant_id: variants.pluck("id"))
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

        sleep 2
      end
    end
    binding.pry
  end

  task :compile_product_and_inventory => :environment do
    variants = []
    inventory_items = []
    s = ShopifyApi.new(
      auth_key: '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'
    )
    products = s.products
    products.each do |p|
      mapped_vars = p["variants"].map do |z|
        z["product_title"] = p['title']
        z
      end
      variants.concat(mapped_vars)
    end
    variants.in_groups_of(100, false) do |group|
      inv_items = s.inventory_items(ids: group.pluck("inventory_item_id").join("%2C"))
      inventory_items.concat(inv_items)
    end

    mapped_vars = variants.map do |v|
      v["inv_cost"] = inventory_items.find { |x| x['id'] == v['inventory_item_id'] }.dig("cost")
      v
    end
    binding.pry
  end

  task :find_com => :environment do
    hits = []
    arr = JSON.parse(File.read('comparison.json'))
    arr.each do |a|
      light_cost = a['light_cost']
      light_price = a['light_price']
      s_price = a['shopify_price']
      s_cost = a['shopify_cost']

      if light_cost.to_f != s_cost.to_f || light_price.to_f != s_price.to_f || light_cost == '0'
        hits << a
      end
    end
    headers = ['Name', 'Light Price', 'Light Cost', 'Shopify Price', 'Shopify Cost', 'Lightspeed ID', 'Zero Cost']
    data = CSV.generate(headers: true) do |csv|
      csv << headers
      hits.each do |sale|
        arr = [
          sale['name'],
          sale['light_price'],
          sale['light_cost'],
          sale['shopify_price'],
          sale['shopify_cost'],
          sale['light_id'],
          sale['light_cost'] == '0'
        ]
        csv << arr
      end
    end
    File.write("product_pricing_updates.csv", data)
    binding.pry
  end

  task :seed_db_create => :environment do
    hits = []
    s = ShopifyApi.new(
      auth_key: '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'
    )
    l = LightApi.first
    payload = []
     payload.each do |x|
       bp = BaseProduct.find_by(shopify_variant_id: x['gecko_id'].to_s)
       if bp.nil?
         new_product = BaseProduct.create(
           shopify_variant_id: x['gecko_id'].to_s,
           shopify_product_id: s.variant(id: x['gecko_id'].to_s)['variant']['product_id'].to_s,
           upc: x['upc'],
           sku: x['sku']
         )
         l.refresh_token
         new_ls_product = l.create_product(
           name: x['name'],
           sku: x["sku"],
           upc: x["upc"],
           cost: x["cost"].to_f,
           wholesale_cost: x['wholesale_cost'].to_f,
           gecko_id: x["gecko_id"].to_s
         )
         puts '________NEW_LS_PRODUCT________________'
         puts new_ls_product
         puts '__________NEW_LS_PRODUCT_______________'
       else
         puts '_____________FOUND________________'
       end
     end
     binding.pry
  end

  task :not_in_ls_process => :environment do
    hits = []
    products = JSON.parse(File.read('products.json'))
    light_products = JSON.parse(File.read('light_products.json'))
    missing = JSON.parse(File.read('ls_missing.json'))
    s = ShopifyApi.new(
      auth_key: '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'
    )
    l = LightApi.first
    mapped_prods = missing.each do |missing_product|
      shopify_product = products.find { |x| x['id'].to_s == missing_product['product_id'].to_s }
      shopify_skus = shopify_product['variants'].map { |x| x['sku'] }
      shopify_upcs = shopify_product['variants'].map { |x| x['barcode'] }
      found_name = light_products.find { |x| shopify_skus.include?(x['customSku']) || shopify_upcs.include?(x['upc']) }
      if !found_name.nil?
        variant = shopify_product['variants'].find {|x| x['sku'] == found_name['customSku'] || x['barcode'] == found_name['upc'] }
        hits << {
          light_name: found_name['description'],
          light_id: found_name['itemID'],
          upc: found_name['upc'],
          sku: found_name['customSku'],
          shopify_variant: variant['id'],
          shopify_product_id: variant['product_id'],
          shopify_upc: variant['barcode'],
          shopify_sku: variant['sku']
        }.as_json
      end
    end
    filter = hits.select do |mp|
      bp = BaseProduct.find_by(
        light_id: mp['light_id'],
        shopify_variant_id: mp['shopify_variant'].to_s,
        shopify_product_id: mp['shopify_product_id'].to_s
      )
      bp.nil?
    end
    binding.pry
  end

  task :not_in_db_process => :environment do
    payload = []
    products = JSON.parse(File.read('products.json'))
    light_products = JSON.parse(File.read('light_products.json'))
    missing = JSON.parse(File.read('not_in_db.json'))
    s = ShopifyApi.new(
      auth_key: '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'
    )
    l = LightApi.first
    missing.each do |missing_product|
      bp = BaseProduct.new(shopify_variant_id: missing_product['id'].to_s, shopify_product_id: missing_product['product_id'])
      shopify_product = products.find { |x| x['id'].to_s == bp.shopify_product_id }
      variant = shopify_product['variants'].find {|z| z['id'].to_s == bp.shopify_variant_id }
      inventory_item = s.inventory_item(id: variant["inventory_item_id"]).dig('inventory_item')
      payload << {
        name: shopify_product['title'] + ' ' + variant['title'],
        sku: variant['sku'],
        upc: variant['barcode'],
        cost: variant['price'],
        wholesale_cost: inventory_item['cost'],
        gecko_id: variant['id']
      }.as_json
    end
    binding.pry
  end

  task :wondering => :environment do
    products = JSON.parse(File.read('products.json'))
    light_products = JSON.parse(File.read('light_products.json'))
    binding.pry
  end

  task :compare_both => :environment do
    not_in_db = []
    ls_missing = []
    existing = []
    products = JSON.parse(File.read('products.json'))
    light_products = JSON.parse(File.read('light_products.json'))
    s = ShopifyApi.new(
      auth_key: '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'
    )

    products.each do |sp|
      id = sp["id"]
      variants = sp["variants"]
      variants.each do |x|
        base = BaseProduct.find_by(shopify_variant_id: x['id'].to_s, shopify_product_id: id.to_s)
        if base.nil?
          not_in_db << { id: x['id'], product_id: id.to_s }
          next
        end
        if base.present? && base.light_id == ''
          ls_missing << { id: x['id'], product_id: id.to_s }
          next
        end
        if x['price'] == '0'
          binding.pry
        end
        if base.present? && base.light_id != ''
          product_found_ls = light_products.find { |l| l['itemID'] == base.light_id }
          next if product_found_ls.nil?
          prices_found = product_found_ls["Prices"]["ItemPrice"]
          inventory_item = s.inventory_item(id: x["inventory_item_id"]).dig('inventory_item')
          comparison_obj = {
            name: product_found_ls['description'],
            light_price: prices_found.find { |x| x["useType"] == 'Default' }.dig('amount'),
            light_cost: product_found_ls["defaultCost"],
            light_id: base.light_id,
            shopify_price: x['price'],
            shopify_cost: inventory_item['cost']
          }
          existing << comparison_obj.as_json
          sleep 1
        end
      end
    end
    File.open("comparison.json", "w+") { |file| file.write(existing.to_json) }
    # File.open("not_in_db.json", "w+") { |file| file.write(not_in_db.to_json) }
    # File.open("ls_missing.json", "w+") { |file| file.write(ls_missing.to_json) }
    binding.pry
  end

  task :light_prod_all => :environment do
    l = LightApi.first
    l.refresh_token
    products = l.get_products
    File.open("light_products.json", "w+") { |file| file.write(products.to_json) }
  end

  task :shopify_products_all => :environment do
    shopify = ShopifyApi.new(
      auth_key: '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'
    )
    products = shopify.products
    File.open("products.json", "w+") { |file| file.write(products.to_json) }
  end

  task :product_query => :environment do
    l = LightApi.last
    l.refresh_token
    po = l.purchase_order(id: "1260")
    payload = l.create_dashboard_payload(po)
    binding.pry
  end

  task :old_db => :environment do
    l = LightApi.last
    mappings = file.map do |q|
      l.refresh_token
      product = l.get_product(id: q["light_id"])
      puts '_________________________________________'
      puts product
      puts '__________________________________________'
      sleep 1
      product
    end
    binding.pry
  end

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

  # products are missing in LS, but exist in Shopify. Map for reporting
  task :map_problem_shopify_products => :environment do
    not_found = BaseProduct.where(light_id: '')
    shopify = ShopifyApi.new(
      auth_key: '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'
    )
    mapped = not_found.map do |q|
      product = shopify.product(id: q.shopify_product_id)
      variant = product["product"]["variants"].find { |l| l["id"].to_s == q.shopify_variant_id }
      sleep 1
      {
        name: product["product"]["title"] + ' ' + variant["title"],
        product_name: product["product"]["title"],
        shopify_product_id: q.shopify_variant_id,
        shopify_variant_id: q.shopify_variant_id
      }
    end
    binding.pry
  end


  task :transfer_db_values => :environment do
    pl.each do |p|
      bp = BaseProduct.find_by(upc: p["upc"])
      if !bp.nil?
        bp.update(light_id: p["id"])
      else
        binding.pry
      end
    end
    binding.pry
  end

  task :process_products => :environment do
    products = JSON.parse(File.read('products.json'))
    items = []
    not_found_products = []
    selected = products.each do |g|
      bp = BaseProduct.find_by(sku: g["customSku"]) || BaseProduct.find_by(upc: g["manufacturerSku"]) || BaseProduct.find_by(upc: g["upc"])
      if !bp.nil?
        bp.update(light_id: g["itemID"])
      end
    end

    binding.pry
  end
  task :fetch_products => :environment do
    # Get product dump from LS
    l = LightApi.last
    l.refresh_token
    products = l.get_products
    File.open("products.json", "w+") { |file| file.write(products.to_json) }
  end

  task :s_products => :environment do
    # Get product dump from LS
    variants = []
    l = LightApi.first
    s = ShopifyApi.last
    products = s.products
    products.each do |p|
      mapped_vars = p["variants"].map do |z|
        z["product_title"] = p['title']
        z
      end
      variants.concat(mapped_vars)
    end
    not_found = variants.select do |v|
      bp = BaseProduct.find_by(shopify_variant_id: v['id'].to_s, shopify_product_id: v['product_id'].to_s)
      bp.nil?
    end
    puts '__________LENGTH___________-'
    puts not_found.length
    puts '__________LENGTH___________'
    not_found.each do |np|
      inventory_item = s.inventory_item(id: np["inventory_item_id"]).dig('inventory_item')
      new_product = BaseProduct.create(
        shopify_variant_id: np['id'].to_s,
        shopify_product_id: np['product_id'].to_s,
        upc: np['barcode'],
        sku: np['sku']
      )
      l.refresh_token
      new_ls_product = l.create_product(
        name: np['product_title'] + ' ' + np["title"],
        sku: np["sku"],
        upc: np["barcode"],
        cost: np["price"].to_f,
        wholesale_cost: inventory_item["cost"].to_f,
        gecko_id: np["id"].to_s
      )
      puts '_____________NEW LS PRODUCT____________________'
      puts new_ls_product
      puts '_____________NEW LS PRODUCT____________________'

      new_product.update(light_id: new_ls_product["Item"]['itemID'])
      sleep 2
    end
    binding.pry
  end

  task :fetch_sales => :environment do
    # this will fetch the sales for the past 7 days for each of the Shops with LS.
    # we want to see if our db has all the products locally

    # FETCH SALES => Write File
    # l = LightApi.last
    # l.refresh_token
    # sales = l.get_sales
    # File.open("out.txt", "w+") { |file| file.write(sales) }
    # binding.pry

    # Use File
    sales = JSON.parse(File.read('out.json'))
    items = []
    not_found_products = []
    sales.map do |x|
      # .map { |q| q&.dig("Item") }
       sale_lines = x.dig("SaleLines", "SaleLine")
       if sale_lines.is_a? Hash
         item = sale_lines.dig("Item")
         items << item
       else
         next if sale_lines.nil?
         item = sale_lines.map do |g|
           g&.dig("Item")
         end
         items.concat(item)
       end
     end
     sant = items.compact.each do |g|
       bp = BaseProduct.find_by(sku: g["customSku"]) || BaseProduct.find_by(upc: g["manufacturerSku"])
       if bp.nil?
         not_found_products << { name: g["description"], id: g["itemID"], custom_sku: g["customSku"], man_sku: g["manufacturerSku"] }.as_json
         next
       end
       # bp.update(light_id: g["itemID"])
       # {
       #   manufacturer_sku: g["manufacturerSku"],
       #   archived: g["archived"],
       #   custom_sku: g["customSku"],
       #   description: g["description"],
       #   base_product: BaseProduct.where(sku: g["customSku"])
       # }
     end
     # trying to find out how many sale lines are affected by missing data (292 missing base products from LS)
     sale_line_missings = []
     sales.compact.map do |g|
       sale_lines = g.dig("SaleLines", "SaleLine")
       if sale_lines.is_a? Hash
         item = sale_lines.dig("Item")
         sale_line_missings << item
       else
         next if sale_lines.nil?
         item = sale_lines.map do |g|
           g&.dig("Item")
         end
         sale_line_missings.concat(item)
       end
    end
    counted = not_found_products.count { |x| sale_line_missings.compact.pluck("itemID").include?(x["id"]) }
    binding.pry
  end

  task :seed_shopify_products => :environment do
    # for db init we will need to get all shopify products, then get all
    # LS products. Find the products by UPC, and then add them as base products
    # we use these products to be able to build purchase orders safely so
    # products in LS but not in Shopify are skipped

    # NOTE: Shopify has products which has_many variants. Each of our base
    # products in the DB are variants
    shopify = ShopifyApi.new(
      auth_key: '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'
    )
    products = shopify.products
    base_products = products.map do |product|
      obj = { id: product["id"], variants: [] }.as_json
      pl = product["variants"].length
      option_count = 0
      sl = product["options"].each { |x| option_count += x["values"].length }
      product["variants"].each do |variant|
        bp = BaseProduct.new(
          light_id: '',
          shopify_variant_id: variant["id"],
          shopify_product_id: obj["id"],
          upc: variant["barcode"],
          sku: variant["sku"]
        )
        obj["variants"] << bp
      end
      obj
    end
    base_products.pluck("variants").flatten.each { |x| x.save! }
  end

  task :shopify => :environment do
    shopify = ShopifyApi.new(
      auth_key: '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'
    )

    products = shopify.products
    variant_ids = products.dig("products").first.dig("variants").pluck("id")
    payload = {
      line_items: variant_ids.map.each_with_index do |g, i|
        { variant_id: g, quantity: (6 * i) + 1 }
      end
    }
    order = shopify.create_order(payload)
    binding.pry
  end

  task :cp_hook => :environment do
    shopify = ShopifyApi.new(
      auth_key: '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'
    )
    # hooks = shopify.hooks
    hook = shopify.create_hook(
      action: 'products/update',
      url: 'https://tvs-sp-qb-integration.herokuapp.com/api/v1/product_update'
    )
    binding.pry
  end

  task :process_new_updates => :environment do
    s = ShopifyApi.last
    l = LightApi.last
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
            puts '_____________________V_________________'
            puts v["sku"]
            puts v["barcode"]
            puts '_______________________________________'
            puts v
            puts '____________________V___________________'
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
  # END OLD SCRIPTS
end



# HOOKS
# CREATE PRODUCT HOOK
# {"webhook"=>
#   {
#    "id"=>1054165729332,
#    "address"=>"https://tvs-sp-qb-integration.herokuapp.com/api/v1/product_create",
#    "topic"=>"products/create",
#    "created_at"=>"2022-06-08T05:26:42-04:00",
#    "updated_at"=>"2022-06-08T05:26:42-04:00",
#    "format"=>"json",
#    "fields"=>[],
#    "metafield_namespaces"=>[],
#    "api_version"=>"2022-04",
#    "private_metafield_namespaces"=>[]
#   }
#  }
# UPDATE PRODUCT HOOK
# {"webhook"=>
#   {
#    "id"=>1054165762100,
#    "address"=>"https://tvs-sp-qb-integration.herokuapp.com/api/v1/product_update",
#    "topic"=>"products/update",
#    "created_at"=>"2022-06-08T05:28:14-04:00",
#    "updated_at"=>"2022-06-08T05:28:14-04:00",
#    "format"=>"json",
#    "fields"=>[],
#    "metafield_namespaces"=>[],
#    "api_version"=>"2022-04",
#    "private_metafield_namespaces"=>[]
#   }
#  }
