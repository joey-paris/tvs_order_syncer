require 'httparty'
class LightApi < ApplicationRecord
  include HTTParty

  def get_reconciles
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/InventoryCountReconcile.json", headers: headers).parsed_response
  end

  def create_reconcile(params)
    payload = {
      "inventoryCountID": params[:count_id]
    }
    self.class.post("https://api.lightspeedapp.com/API/Account/#{account}/InventoryCountReconcile.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def get_item_payload(params)
    items = []
     ids_to_params = "%5B%22" + params[:ids].compact.join("%22%2c%22") + "%22%5D"
     counter = 0
     while counter < 1000
       self.refresh_token
       sleep 3
       res = self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?offset=#{counter}&load_relations=%5B%22ItemShops%22%5D&itemID=IN,#{ids_to_params}", headers: headers).parsed_response

       payload = res.dig("Item")
       if payload.nil? || payload.empty?
         break
       end
       if payload.class == Hash
         zz = [payload].map { |x| x.dig("ItemShops","ItemShop").map { |z| { item: z["itemID"], qoh: z["qoh"], shop: z["shopID"] } if z["shopID"] == params[:shop_id] }.compact }.compact
         items << zz
         break
       end
       items << payload.map { |x| x.dig("ItemShops","ItemShop").map { |z| { item: z["itemID"], qoh: z["qoh"], shop: z["shopID"] } if z["shopID"] == params[:shop_id] }.compact }.compact
       counter += 100
     end
     items.flatten
  end

  def create_dashboard_payload(order_obj)
    shops = [
      {:name=>"TVS - Rochester", :shop_id=>"1", :t_id => "72294051"},
      {:name=>"TVS - DEQ", :shop_id=>"2", :t_id => "72294055"},
      {:name=>"TVS - Gratiot", :shop_id=>"3", :t_id => "72294056"},
      {:name=>"TVS - Clinton", :shop_id=>"4", :t_id => "72294052"},
      {:name=>"TVS - Crooks", :shop_id=>"5", :t_id => "72294053"},
      {:name=>"TVS - Shelby", :shop_id=>"6", :t_id => "72294054"},
      {:name=>"TVS - Woodward", :shop_id=>"7", :t_id => "72294066"},
      {:name=>"TVS - Chesterfield", :shop_id=>"8", :t_id => "72294074"},
      {:name=>"TVS - Orchard Lake", :shop_id=>"9", :t_id => "72294101"},
      {:name=>"TVS - Madison", :shop_id=>"16", :t_id => "89927404"},
      {:name=>"TVS - Novi", :shop_id=>"17", :t_id => "108582188"},
      {:name=> "TVS - Rochester Hills", :shop_id=>"18", :t_id=>"108582188"}
    ]
    self.refresh_token
    sleep 5
    order = self.purchase_order(id: order_obj["Order"]["orderID"])

    waves = order["Order"]["OrderLines"]["OrderLine"].pluck("itemID").in_groups_of(100)
    # second_wave = order["Order"]["OrderLines"]["OrderLine"].pluck("itemID").reject {|x| first_wave.include?(x) }

    item_quantities = []

    waves.each do |re|
      self.refresh_token
      sleep 2
      item_init = self.get_item_payload(ids: re, shop_id: order_obj["Order"]["shopID"])
      item_init.each { |x| item_quantities << x }
    end

    line_items = order["Order"]["OrderLines"]["OrderLine"]
                  .pluck("itemID", "quantity", "orderLineID")
                  .map do |x|
                    item_qt = item_quantities.find { |z| z[:item] == x[0].to_s }&.dig(:qoh)
                    bp =  BaseProduct.find_by(light_id: x[0])
                    if item_qt.nil?

                    end
                    {
                      item_id: x[0],
                      current_quantity: item_qt,
                      quantity: x[1],
                      order_line_id: x[2],
                      shopify_quantity: 0,
                      shopify_id: bp&.shopify_variant_id,
                      shopify_product_id: bp&.shopify_product_id
                     }.as_json
                  end
    shopify = ShopifyApi.last
    shopify_req = shopify.products_by_id(ids: line_items.pluck("shopify_product_id").compact)
    line_items.each do |z|
      payload_find = shopify_req.find { |x| x["id"] == z["shopify_id"].to_i }
      if payload_find.nil?
        puts z
        puts "skip"
        next
      end
      z["shopify_quantity"] = payload_find["inventory_quantity"]
      z["item_name"] = (payload_find["product_name"] || "")  + " " + payload_find["title"]
    end
    shop_name = shops.find { |z| z[:shop_id] == order["Order"]["shopID"] }
    payload = {
      "order_id": order["Order"]["orderID"],
      "order_name": "#{shop_name&.dig(:name)}: #{Date.today.to_s}",
      "line_items": line_items,
      "group_name": "Week of #{Date.today.to_s}"
    }

    self.class.post("https://tvs-stores-po-app.herokuapp.com/hooks/order_create_hook", headers: { "Content-Type": "application/json" }, body: JSON.dump(payload)).parsed_response
  end

  def get_counts
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/InventoryCount.json", headers: headers).parsed_response
  end

  def get_sales_issue
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Sale.json?load_relations=%5B%22SaleLines.Item%22%5D&timeStamp=><,#{Time.zone.now - 7.days},#{Time.zone.now}&offset=0", headers: headers).parsed_response
  end

  def update_purchase_order_status(params)
    payload = {
      "CustomFieldValues": {
      "CustomFieldValue": {
         "customFieldID": "1",
         "value": params[:gecko_id]
        }
      }
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Order/#{params[:id]}.json")
  end

  def update_item_gecko_count(params)
    payload = {
      "CustomFieldValues": {
      "CustomFieldValue": {
         "customFieldID": "2",
         "value": params[:gecko_count]
        }
      }
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{params[:id]}.json",  body: JSON.dump(payload), headers: headers).parsed_response
  end

  def get_sale(params)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Sale/#{params[:id]}.json?load_relations=%5B%22SaleLines.Item%22%5D", headers: headers).parsed_response
  end

  def get_sales_basic(params)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Sale.json?load_relations=%5B%22SaleLines.Item%22%5D", headers: headers).parsed_response
  end

  def get_recent_purchase_orders
    current_date = Date.today.end_of_day
    former_date = Date.today - 7.days + 9.hours
    res = self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Order.json?load_relations=%5B%22CustomFieldValues%22%5D&timeStamp=><,#{former_date},#{current_date}", headers: headers).parsed_response
    res
  end

  def get_sales
    offset = 0
    full_sales = []
    current_date = Date.today + 5.hours
    former_date = Date.today - 7.days + 9.hours
    counter = 0
    while offset < 1000000
      self.refresh_token
      sleep 2
      sales = self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Sale.json?load_relations=%5B%22SaleLines.Item%22%5D&timeStamp=><,#{former_date},#{current_date}&offset=#{offset}", headers: headers).parsed_response
      if sales["httpCode"]
        puts "________PROBLEM______________"
        puts offset
        puts sales
        puts "________PROBLEM______________"
      end
      break if sales["Sale"].nil?
      sales["Sale"].each do |s|
        full_sales << s
      end
      offset += 100
      sleep 2
    end
    full_sales
  end

  def get_products
    offset = 0
    full_products = []
    counter = 0
    while offset < 1000000
      self.refresh_token
      sleep 2
      items = self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?load_relations=%5B%22CustomFieldValues%22%2c%22ItemShops%22%5D&offset=#{offset}", headers: headers).parsed_response
      if items["httpCode"]
        puts "________PROBLEM______________"
        puts offset
        puts "________PROBLEM______________"
      end
      break if items["Item"].nil?
      items["Item"].each do |s|
        full_products << s
      end
      offset += 100
      sleep 2
    end
    full_products
  end

  def delete_product(params)
    self.class.delete("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{params[:id]}.json", headers: headers).parsed_response
  end

  def inventory_count_item
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/InventoryCountItem.json", headers: headers).parsed_response
  end

  def create_count(params)
    payload = {
      "shopID": params[:shop_id],
      "name": params[:name]
    }
    self.class.post("https://api.lightspeedapp.com/API/Account/#{account}/InventoryCount.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def update_from_ls(order)
    self.refresh_token
    order_lines = order["Order"]["OrderLines"]["OrderLine"]
    order_id = order["Order"]["orderID"]
    shop_id = order["Order"]["shopID"]
    db_items = OrderLineItem.where(order_id: order_id).as_json
    plucked_order_line_ids = order_lines.pluck("orderLineID")
    base_products = BaseProduct.all.as_json
    order["Order"]["OrderLines"]["OrderLine"].each do |x|
      quantity = x["quantity"]
      found_item = db_items.find {|z| z["order_line_item_id"] == x["orderLineID"] }

      if found_item.nil?
        item_id = x["itemID"]
        base_product = base_products.find {|q| q["light_id"] == item_id }
        next if base_product.nil?
        new_item = OrderLineItem.create(
          order_line_item_id: x["orderLineID"],
          order_id: order_id,
          quantity: quantity,
          shop_id: shop_id,
          base_product_id: base_product["id"]
        )
        puts "__________NEW_____________"
        puts new_item
        puts "__________NEW_____________"
      else
        current_quantity = found_item["quantity"]
        db_item = OrderLineItem.find(found_item["id"])
        if current_quantity != quantity
          db_item.update!(quantity: quantity)
          puts "_______UPDATE__________"
          puts db_item.as_json
          puts "_______UPDATE__________"
        end
      end
    end
    removed_items = OrderLineItem.where(order_id: order_id).where.not(order_line_item_id: plucked_order_line_ids)
    puts "__________REMOVED___________"
    puts removed_items.count
    puts "__________REMOVED___________"
    removed_items.each { |x| x.destroy! }

    puts "________FINISHED_______"
    puts "_________FINISHED______"
  end

  def build_orders
    shopify = ShopifyApi.last
    self.refresh_token
    grouped_products = self.sales_process
    purchase_orders = []
    shopify_variants = shopify.products.pluck("variants").flatten
    # ** - below you will see x == "0". You can exclude the Shop IDs of already built orders if the job fails
    # and you need to re-run the order building job to build out the rest of the orders.
    # when you check the production logs you will see prints of every line item. You will find the order ID
    # in that print. Archive that order on LS dashboard, and reject all the jobs before it. You will find the shop IDs
    # in the create dashboard payload method as an arr of objects
    # grouped_products.keys.reject { |x| x == "0" }.each_with_index do |s, i|
    grouped_products.keys.reject { |x| x == "0" || x == "1" || x == "2" }.each_with_index do |s, i|
      if grouped_products[s].empty?
        puts "ISSSUE!"
        next
      end
      sleep 2
      self.refresh_token
      sleep 2
      purchase_order = self.create_purchase_order(shop_id: s)
      puts "____________"
      puts purchase_order
      puts "____________"
      if purchase_order["httpCode"]
        sleep 20
        purchase_order = self.create_purchase_order(shop_id: s)
        puts "____________"
        puts purchase_order
        puts "____________"
      end
      if !purchase_order["Order"]
        return
      else
        order_id = purchase_order["Order"]["orderID"]
        purchase_orders << purchase_order
        products = grouped_products[s]
        variants = shopify_variants.select { |x| products.pluck("shopify_id").include?(x["id"].to_s) }

        # END
        products.each do |op|
          base_product = BaseProduct.find_by(light_id: op["item"])
          next if base_product.nil?

          shopify_obj = variants.find do |x|
            x && x["id"] && x["id"].to_s == base_product.shopify_variant_id
          end
          if shopify_obj.nil?
            puts "no shopify obj"
            puts op
            puts "no shopify obj"
            next
          end

          shopify_stock = shopify_obj["inventory_quantity"]
          shopify_out = shopify_stock.to_i <= 0
          if shopify_out
            puts "_________SKIPPED_____________"
            puts op
            puts "_________SKIPPED_____________"
            next
            sleep 1
          end
          order_line_item = self.create_order_line_item(
            order_id: order_id,
            product_id: op["item"],
            cost: op["cost"],
            quantity: op["quantity"]
          )
          if base_product && order_line_item["httpCode"].nil?
            order_line_item_id = order_line_item.dig("OrderLine", "orderLineID")
            if order_line_item_id.nil?
              puts "_______PROBLEM__________"
              puts order_line_item
              puts "______PROBLEM____________"
              next
            end
            # ol_db = OrderLineItem.create(
            #   order_line_item_id: order_line_item_id,
            #   base_product_id: base_product.id,
            #   shop_id: s,
            #   order_id: order_id,
            #   quantity: op["quantity"]
            # )
          end
          if order_line_item["httpCode"]
            sleep 6
            self.refresh_token
            order_line_item = self.create_order_line_item(
              order_id: order_id,
              product_id: op["item"],
              cost: op["cost"],
              quantity: op["quantity"]
            )
            next if order_line_item["OrderLine"].nil?
            if base_product
              order_line_item_id = order_line_item["OrderLine"]["orderLineID"]
              # ol_db = OrderLineItem.create(
              #   base_product_id: base_product.id,
              #   order_line_item_id: order_line_item_id,
              #   shop_id: s,
              #   order_id: order_id,
              #   quantity: op["quantity"]
              # )
            end
            puts "___________OL_________________"
            puts order_line_item
            puts "___________OL__________________"
          end
        end
      end
    end
    # OrderJob.create(order_payload: purchase_orders)
    purchase_orders
  end

  def process_to_gecko(params)
    sleep 4
    self.refresh_token
    sleep 3
    order = self.purchase_order(id: params[:id])
    puts "_____________ORDER_____________"
    puts order
    puts "_____________ORDER_____________"
    sleep 3
    line_items = if order["Order"]["OrderLines"]["OrderLine"].is_a? Array
      order["Order"]["OrderLines"]["OrderLine"].map do |p|
        next if p["quantity"] == "0"
        {
          variant_id: BaseProduct.find_by(light_id: p["itemID"]).gecko_id,
          quantity: p["quantity"],
          price: p["price"]
        }
      end
    else
      [{
        variant_id: BaseProduct.find_by(light_id: p["itemID"]).gecko_id,
        quantity: order["Order"]["OrderLines"]["OrderLine"]["quantity"],
        price: order["Order"]["OrderLines"]["OrderLine"]["price"]
      }]
    end
    puts "_____LINE ITEMS______"
    puts line_items
    puts "_____LINE ITEMS______"
    shop_id = order["Order"]["shopID"]
    gecko_api = GeckoApi.find(35)
    gecko_api.refresh_token
    company_parent = gecko_api.get_company(id: gecko_api.find_shop(shop_id: shop_id))
    puts "___________COMPANY PARENT__________________"
    puts company_parent
    puts "___________COMPANY PARENT__________________"

    company = company_parent["company"]["id"]
    company_loc = company_parent["company"]["address_ids"][0]
    sales_order = gecko_api.create_sales_order(
      billing: company_loc,
      shipping: company_loc,
      company_id: company,
      order_line_items: line_items.reject { |x| x.nil? || x[:quantity] == "0" }
    )
    if sales_order["errors"]
      sales_order = gecko_api.create_sales_order_build(
        billing: company_loc,
        shipping: company_loc,
        company_id: company,
        order_line_items: line_items.reject { |x| x.nil? || x[:quantity] == "0" }
      )
    end
    puts "____SALES ORDER_____"
    puts sales_order
    puts "____SALES ORDER_____"
    purchase_order_job = PurchaseOrderJob.find_by(order_id: params[:id]).update!(completed: true)
    self.update_po_cv(id: params[:id])
    parent_gecko = GeckoSaleOrder.create(sale_order: sales_order, purchase_order_id: params[:id], sales_order_id: sales_order["order"]["id"])
    parent_gecko
  end

  # BEEEIGN

  def process_to_shopify(params)
  sleep 4
  self.refresh_token
  sleep 3
  order = self.purchase_order(id: params[:id])
  puts "_____________ORDER_____________"
  puts order
  puts "_____________ORDER_____________"
  sleep 3
  line_items = if order["Order"]["OrderLines"]["OrderLine"].is_a? Array
    order["Order"]["OrderLines"]["OrderLine"].map do |p|
      next if p["quantity"] == "0"
      {
        variant_id: BaseProduct.find_by(light_id: p["itemID"]).shopify_variant_id,
        quantity: p["quantity"],
        price: p["price"]
      }
    end
  else
    [{
      variant_id: BaseProduct.find_by(light_id: p["itemID"]).shopify_variant_id,
      quantity: order["Order"]["OrderLines"]["OrderLine"]["quantity"],
      price: order["Order"]["OrderLines"]["OrderLine"]["price"]
    }]
  end

  shop_id = order["Order"]["shopID"]
  shopify_api = ShopifyApi.last
  shop_base = shopify_api.find_shop(shop_id: shop_id)
  sleep 3
  sales_order = shopify_api.create_order(
    lines: line_items,
    customer_id: shop_base[:t_id],
    shop: shop_base[:name]
  )
  puts '_____________________SALES______________________'
  puts sales_order
  puts '_____________________SALES______________________'
  # purchase_order_job = PurchaseOrderJob.find_or_create_by(order_id: params[:id]).update(completed: true)

  # This marks gecko_completed
  self.update_po_cv(id: params[:id])

  shopify_sales_order_base = ShopifySalesOrder.create(
    sale_order: sales_order,
    purchase_order_id: params[:id],
    sales_order_id: sales_order["order"]["id"]
  )

  shopify_sales_order_base.as_json
end

  def update_po_cv(params)
    self.refresh_token
    sleep 1
    payload = {
      "CustomFieldValues": {
        "CustomFieldValue": {
          "customFieldID": "2",
          "value": "true"
        }
      }
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Order/#{params[:id]}.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def headers
    {
      'Authorization': "Bearer #{light_key}",
      "Content-Type": "application/json"
    }
  end

  def create_order_line_item(params)
    payload = {
      "quantity": params[:quantity].to_i,
      "price": params[:cost].to_f,
      "numReceived": "0",
      "itemID": params[:product_id].to_i,
      "orderID": params[:order_id].to_i
    }
    self.class.post(
      "https://api.lightspeedapp.com/API/Account/#{account}/OrderLine.json",
      headers: headers,
      body: JSON.dump(payload),
      timeout: 10
    ).parsed_response
  end

  def update_order_line_item(params)
    payload = {
      "quantity": params[:quantity].to_i,
      "price": params[:cost].to_f,
      "numReceived": "0",
      "itemID": params[:product_id].to_i,
      "orderID": params[:order_id].to_i
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/OrderLine/#{params[:id]}.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def update_order_line_item_price(params)
    payload = {
      "price": params[:cost].to_f,
      "itemID": params[:product_id].to_i,
      "orderID": params[:order_id].to_i
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/OrderLine/#{params[:id]}.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def get_accounts
    self.class.get("https://api.lightspeedapp.com/API/Account.json", headers: headers).parsed_response
  end

  # def get_products
  #   self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?load_relations=%5B%22CustomFieldValues%22%2c%22ItemShops%22%5D", headers: headers).parsed_response
  # end

  def get_paged_products(params)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?limit=100&offset=#{params[:offset]}&load_relations=%5B%22CustomFieldValues%22%5D", headers: headers).parsed_response
  end

  def get_products_custom
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?load_relations=%5B%22CustomFieldValues%22%5D", headers: headers).parsed_response
  end

  def get_product(params)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{params[:id]}.json?load_relations=%5B%22ItemShops%22%5D", headers: headers).parsed_response
  end

  def get_custom_product(params)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{params[:id]}.json?load_relations=%5B%22CustomFieldValues%22%2c%22ItemShops%22%5D", headers: headers).parsed_response
  end

  def create_product(params)
    payload = {
      "description": params[:name],
      "defaultCost": params[:wholesale_cost],
      "manufacturerSku": params[:upc],
      "customSku": params[:sku],
      "Prices": {
        "ItemPrice": [
            {
              "amount": params[:cost],
              "useTypeID": "1",
              "useType": "Default"
            }
          ]
        },
        "CustomFieldValues": {
        "CustomFieldValue": {
           "customFieldID": "1",
           "value": params[:gecko_id]
          }
        }
      }
    self.class.post("https://api.lightspeedapp.com/API/Account/#{account}/Item.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def update_product(params)
    payload = {
      "Prices": {
        "ItemPrice": [
          {
            "amount": params[:price],
            "useType": "Default"
          }
        ]
      }
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{params[:id]}.json", body: JSON.dump(payload), headers: headers).parsed_response
  end

  def update_ls_product(params)
    payload = {
      "description": params[:name],
      "defaultCost": params[:wholesale_cost],
      "manufacturerSku": params[:upc],
      "customSku": params[:sku],
      "Prices": {
        "ItemPrice": [
          {
            "amount": params[:price],
            "useType": "Default"
          }
        ]
      },
      "CustomFieldValues": {
      "CustomFieldValue": {
         "customFieldID": "1",
         "value": params[:gecko_id]
        }
      }
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{params[:id]}.json", body: JSON.dump(payload), headers: headers).parsed_response
  end

  def update_inventory(id, payload)
    inventory = {
      "ItemShops": {
        "ItemShop": payload
      }
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{id}.json", body: JSON.dump(inventory), headers: headers).parsed_response
  end

  def inventory_count
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/InventoryCount.json", headers: headers).parsed_response
  end

  def update_item(params)
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{params["itemID"]}.json", headers: headers, body: JSON.dump(params)).parsed_response
  end

  def update_item_sku(params)
    payload = {
      "manufacturerSku": params[:sku]
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Item/#{params[:id]}.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def get_shops
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Shop.json?load_relations=all", headers: headers).parsed_response
  end

  def get_shop(params)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Shop/#{params[:id]}.json?load_relations=all", headers: headers).parsed_response
  end

  # def get_item_shops
  #   self.class.get("https://api.lightspeedapp.com/API/Account/#{@account}/ItemShop.json", headers: headers).parsed_response
  # end

  def purchase_orders(params = nil)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Order.json?load_relations=%5B%22CustomFieldValues%22%2c%22OrderLines%22%2c%22OrderLines%22%5D", headers: headers).parsed_response
  end

  def purchase_order(params)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Order/#{params[:id]}.json?load_relations=%5B%22CustomFieldValues%22%2c%22OrderLines%22%5D", headers: headers).parsed_response
  end

  def order_line(params)
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/OrderLine/#{params[:id]}.json", headers: headers).parsed_response
  end

  def delete_order_line(params)
    self.class.delete("https://api.lightspeedapp.com/API/Account/#{account}/OrderLine/#{params[:id]}.json", headers: headers).parsed_response
  end

  def update_purchase_order_line(params)
    payload = {

    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/OrderLine/#{params[:id]}.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def vendors
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Vendor.json", headers: headers).parsed_response
  end

  def create_purchase_order(params = nil)
    payload = {
      "orderedDate": Time.zone.now,
      "stockInstruction": "Automatic Replenishment order for week of #{Time.zone.now}",
      "shopID": params[:shop_id]
    }
    self.class.post("https://api.lightspeedapp.com/API/Account/#{account}/Order.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def update_purchase_order(params)
    payload = {
      "OrderLines": {
        "OrderLine": [
          {
            "quantity"=>"5",
            "price"=>"5.99",
            "orderID"=>params[:id],
            "itemID"=>"4821"
          },
          {
            "quantity"=>"5",
            "price"=>"20.99",
            "orderID"=> params[:id],
            "itemID"=>"4636"
          }
        ]
      }
    }
    self.class.put("https://api.lightspeedapp.com/API/Account/#{account}/Order/#{params[:id]}.json", headers: headers, body: JSON.dump(payload)).parsed_response
  end

  def authorize(params)
    payload = {
      'code': params[:code],
      'client_secret': client_secret,
      'client_id': client_id,
      'grant_type': 'authorization_code'
    }
    res = self.class.post('https://cloud.lightspeedapp.com/oauth/access_token.php', body: JSON.dump(payload), headers: {"Content-Type": "application/json"}).parsed_response
    res
  end

  def inventory_count
    self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/InventoryCount.json", headers: headers).parsed_response
  end

  def refresh_token
    payload = {
      'refresh_token': refresh,
      'client_secret': client_secret,
      'client_id': client_id,
      'grant_type': 'refresh_token',
    }
    res = self.class.post('https://cloud.lightspeedapp.com/oauth/access_token.php', body: payload).parsed_response
    if res["httpCode"]
      sleep 5
      res = self.class.post('https://cloud.lightspeedapp.com/oauth/access_token.php', body: payload).parsed_response
    end
    @light_key = res["access_token"]
    self.update!(light_key: @light_key)
    res
  end

  def full_inventory
    full_inventory = []
    offset = 0
    sleep 3
    while offset < 10000
      self.refresh_token
      sleep 2
      items = self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?offset=#{offset}&archived=only", headers: headers).parsed_response
      if items["httpCode"]
        sleep 3
        items = self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?offset=#{offset}&archived=only", headers: headers).parsed_response
      end
      break if !items["Item"] || items["Item"].empty?
      full_inventory << items["Item"]
      offset += 100
    end

    full_inventory
  end

  def empty_inventory
    offset = 0
    full_items = {}
    sleep 3
    while offset < 10000
      self.refresh_token
      sleep 1
      items = self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?archived=false&offset=#{offset}&load_relations=%5B%22CustomFieldValues%22%2c%22ItemShops%22%5D", headers: headers).parsed_response
      if items["httpCode"]
        sleep 3
        items = self.class.get("https://api.lightspeedapp.com/API/Account/#{account}/Item.json?archived=false&offset=#{offset}&load_relations=%5B%22CustomFieldValues%22%2c%22ItemShops%22%5D", headers: headers).parsed_response
      end
      break if items["Item"].nil?
      # sometimes comes back as one object...found that out the hardway
      listing = items['Item'].is_a?(Array) ? items['Item'] : [items['Item']]
      listing.each do |z|
      begin
        next if z["archived"] == "true"
      rescue => e
        binding.pry
      end
        z["ItemShops"]["ItemShop"].each do |x|
          if full_items[x["shopID"]]
            next if x["qoh"].to_i > 0
            full_items[x["shopID"]] << { "itemID": x["itemID"], "quantity": "1", "defaultCost": z["defaultCost"] }.as_json
          else
            next if x["qoh"].to_i > 0
            full_items[x["shopID"]] = []
            full_items[x["shopID"]] << { "itemID": x["itemID"], "quantity": "1", "defaultCost": z["defaultCost"] }.as_json
          end

        end
      end
      offset += 100
      sleep 2
    end

    full_items
  end

  def sale_count_by_shop
    self.refresh_token
    payload = self.get_sales
    shops = {"1": [], "2": [], "3": [], "4": [], "5": [], "6": [], "7": [], "8": [], "9": []}.as_json
    returning_values = shops.keys.map do |x|
      total = 0
      counter = payload
                  .reject { |y| y["SaleLines"].nil? || y["completed"] == "false" }
                  .select {|z| z["shopID"] == x }
      total_count = counter.count
      counter.each {|c| total += c["calcAvgCost"].to_f }
      {shop: x, count: total_count, total_cost: total }
    end
    returning_values
  end

  def defining_sales
    self.refresh_token
    payload = self.get_sales
    shops = {"1": [], "2": [], "3": [], "4": [], "5": [], "6": [], "7": [], "8": [], "9": []}.as_json
    payload.reject { |x| x["SaleLines"].nil? || x["completed"] == "false" }.map do |s|
      next if s["shopID"] == "0"
      is_multi = s["SaleLines"]["SaleLine"].is_a? Array
      if is_multi
        s["SaleLines"]["SaleLine"].each do |sl|
          item_id = sl["itemID"]
          next if item_id == 0 || item_id == "0"
          gecko_id = BaseProduct.find_by(light_id: item_id)&.gecko_id
          if gecko_id.nil?
            puts "______________NOT FOUND_______________"
            puts item_id
            puts "______________NOT FOUND_______________"
            next
          end
          payload_2 = {
            quantity: sl["unitQuantity"],
            item: sl["itemID"],
            gecko_id: gecko_id,
            cost: sl["Item"]["defaultCost"]
          }.as_json

          if payload_2["gecko_id"] != "" && payload_2["gecko_id"] != "GECK"
            shops[s["shopID"]] << payload_2
          else
            puts "PROBLEM_______________"
            puts sl
            puts "PROBLEM_______________"
          end
        end

      else
        item_id = s["SaleLines"]["SaleLine"]["itemID"]
        next if item_id == 0 || item_id == "0"
        gecko_id = BaseProduct.find_by(light_id: item_id)&.gecko_id
        if gecko_id.nil?
          puts "______________NOT FOUND_______________"
          puts item_id
          puts "______________NOT FOUND_______________"
          next
        end
        payload_2 = {
          quantity: s["SaleLines"]["SaleLine"]["unitQuantity"],
          item: s["SaleLines"]["SaleLine"]["itemID"],
          gecko_id: gecko_id,
          cost: s["SaleLines"]["SaleLine"]["Item"]["defaultCost"]
        }.as_json

        if payload_2["gecko_id"] != "" && payload_2["gecko_id"] != "GECK"
          shops[s["shopID"]] << payload_2
        else
          puts "PROBLEM_______________"
          puts sl
          puts "PROBLEM_______________"
        end
      end
    end
    puts "___________FINAL BUILD___________________________"
    puts shops["6"]
    puts "___________FINAL BUILD___________________________"
    shops
  end

  def sales_process
    self.refresh_token
    payload = self.get_sales
    empties = self.empty_inventory

    shops = { "1": [], "2": [], "3": [], "4": [], "5": [], "6": [], "7": [], "8": [], "9": [], "16": [], "17": [], "18": [] }.as_json
    payload.reject { |x| x["SaleLines"].nil? || x["completed"] == "false" }.map do |s|
      next if s["shopID"] == "0"
      is_multi = s["SaleLines"]["SaleLine"].is_a? Array
      total_cost = s["calcAvgCost"].to_f
      if is_multi
        s["SaleLines"]["SaleLine"].each do |sl|
          item_id = sl["itemID"]
          archived = sl["archived"]
          next if item_id == 0 || item_id == "0" || archived == "true"
          shopify_id = BaseProduct.find_by(light_id: item_id)&.shopify_variant_id
          if shopify_id.nil?
            puts "______________NOT FOUND_______________"
            puts item_id
            puts "______________NOT FOUND_______________"
            next
          end
          is_included = shops[s["shopID"]].find { |x| x["item"] == item_id }
          if is_included.nil?
            payload_2 = {
              quantity: sl["unitQuantity"],
              item: sl["itemID"],
              shopify_id: shopify_id,
              cost: sl["Item"]["defaultCost"]
            }.as_json

            if payload_2["shopify_id"] != "" && payload_2["shopify_id"] != "GECK" && is_included.nil?
              shops[s["shopID"]] << payload_2
            else
              puts "PROBLEM_______________"
              puts sl
              puts "PROBLEM_______________"
            end

          else
            is_included["quantity"] = (is_included["quantity"].to_i + sl["unitQuantity"].to_i).to_s
          end

        end

      else
        item_id = s["SaleLines"]["SaleLine"]["itemID"]
        archived = s["SaleLines"]["SaleLine"]["archived"]
        next if item_id == 0 || item_id == "0" || archived == "true"
        shopify_id = BaseProduct.find_by(light_id: item_id)&.shopify_variant_id
        if shopify_id.nil?
          puts "______________NOT FOUND_______________"
          puts item_id
          puts "______________NOT FOUND_______________"
          next
        end
        if shops[s["shopID"]].nil?
          puts "_________WHAT____________"
          puts s["shopID"]
          puts s
          puts "_________WHAT____________"
        end
        is_included = shops[s["shopID"]].find { |x| x["item"] == item_id }
        payload_2 = {}

        if is_included.nil?
          payload_2 = {
            quantity: s["SaleLines"]["SaleLine"]["unitQuantity"],
            item: s["SaleLines"]["SaleLine"]["itemID"],
            shopify_id: shopify_id,
            cost: s["SaleLines"]["SaleLine"]["Item"]["defaultCost"]
          }.as_json

          if payload_2["shopify_id"] != "" && payload_2["shopify_id"] != "GECK" && is_included.nil?
            shops[s["shopID"]] << payload_2
          else
            puts "PROBLEM_______________"
            puts sl
            puts "PROBLEM_______________"
          end
        else
          is_included["quantity"] = (is_included["quantity"].to_i + s["SaleLines"]["SaleLine"]["unitQuantity"].to_i).to_s
        end
      end
    end

    # EMPTY INVENTORY START
    empties.keys.each do |ff|
      next if shops[ff].nil?
      current_ids = shops[ff].pluck("item")
      empty_products = empties[ff].reject { |l| current_ids.include?(l["itemID"]) }

      sant_products = empty_products.map do |r|
        base = BaseProduct.find_by(light_id: r["itemID"])
        if base.nil?
          puts "NOT FOUND"
          puts r
          puts "NOT FOUND"
          next
        end
        {
          quantity: "1",
          item: r["itemID"],
          shopify_id: base.shopify_variant_id,
          cost: r["defaultCost"]
        }.as_json
      end.compact

      sant_products.each { |q| shops[ff] << q }
    end
    # EMTPY INVENTORY END

    puts "___________FINAL BUILD___________________________"
    puts shops
    puts "___________FINAL BUILD___________________________"
    shops
  end

  def light_seed(params)
    payload = {
      "description": params[:name],
      "defaultCost": params[:cost],
      "upc": params[:upc],
      "customSku": params[:sku],
      "Prices": {
        "ItemPrice": [
            {
              "amount": params[:cost],
              "useTypeID": "1",
              "useType": "Default"
            }
          ]
        },
        "ItemShops": [

        ],
        "CustomFieldValues": {
        "CustomFieldValue": {
           "customFieldID": "1",
           "value": params[:gecko_id]
          }
        }
      }
  end

  def build_empty_orders
    gecko = GeckoApi.find(35)
    self.refresh_token
    grouped_products = self.empty_inventory
    purchase_orders = []
    puts "_____________________"
    puts grouped_products
    puts "__________________________"
    grouped_products.keys.reject { |x| x == "" }.each_with_index do |s, i|
      next if s == "16" || s == "7"
      # break if i > 0
      if grouped_products[s].empty?
        puts "ISSSUE!"
        next
      end
      sleep 2
      self.refresh_token
      sleep 2
      purchase_order = self.create_purchase_order(shop_id: s)
      puts "____________"
      puts purchase_order
      puts "____________"
      if purchase_order["httpCode"]
        sleep 20
        purchase_order = self.create_purchase_order(shop_id: s)
        puts "____________"
        puts purchase_order
        puts "____________"
      end
      if !purchase_order["Order"]
        return
      else
        order_id = purchase_order["Order"]["orderID"]
        purchase_orders << purchase_order
        products = grouped_products[s]
        products.each do |op|
          base_product = BaseProduct.find_by(light_id: op["itemID"])
          if base_product.nil?
            puts op
            puts "_______________SKIP____________"
            next
          end
          sleep 2
          self.refresh_token
          gecko.refresh_token
          sleep 2
          gecko_stock = gecko.get_variant(id: base_product.gecko_id)
          if gecko_stock["variant"]
            gecko_stock = gecko_stock["variant"]["available_stock"].to_i
          else
            sleep 2
            gecko.refresh_token
            sleep 3
            gecko_obj = gecko.get_variant(id: base_product.gecko_id)
            if gecko_obj["variant"]
              gecko_stock = gecko_obj["variant"]["available_stock"].to_i
            else
              puts "_______GECKO_________________"
              puts gecko_obj
              puts "______GECKO__________________"
              next
            end
          end
          gecko_out = gecko_stock <= 0

          if gecko_out
            puts "_________SKIPPED_____________"
            puts op
            puts "_________SKIPPED_____________"
            next
            sleep 1
          end
          order_line_item = self.create_order_line_item(
            order_id: order_id,
            product_id: op["itemID"],
            cost: op["defaultCost"],
            quantity: op["quantity"]
          )
          if base_product && order_line_item["httpCode"].nil?
            order_line_item_id = order_line_item["OrderLine"]["orderLineID"]
            ol_db = OrderLineItem.create(
              order_line_item_id: order_line_item_id,
              base_product_id: base_product.id,
              shop_id: s,
              order_id: order_id,
              quantity: op["quantity"]
            )
          end
          if order_line_item["httpCode"]
            sleep 5
            order_line_item = self.create_order_line_item(
              order_id: order_id,
              product_id: op["itemID"],
              cost: op["defaultCost"],
              quantity: op["quantity"]
            )
            if base_product
              order_line_item_id = order_line_item["OrderLine"]["orderLineID"]
              ol_db = OrderLineItem.create(
                base_product_id: base_product.id,
                order_line_item_id: order_line_item_id,
                shop_id: s,
                order_id: order_id,
                quantity: op["quantity"]
              )
            end
            puts "___________OL_________________"
            puts order_line_item
            puts ol_db.as_json
            puts "___________OL__________________"
          end
          puts "___________OL_________________"
          puts order_line_item
          puts ol_db.as_json
          puts "___________OL__________________"
        end
        # BaseProduct.where(new_product: true).each do |np|
        #   order_line_item = self.create_order_line_item(
        #     order_id: order_id,
        #     product_id: np.light_id,
        #     cost: np.cost,
        #     quantity: "1"
        #   )
        #   sleep 2
        # end
      end
    end
    BaseProduct.where(new_product: false).update_all(new_product: true)
    OrderJob.create(order_payload: purchase_orders)
    purchase_orders
  end

  def sales_process_loss
    self.refresh_token
    payload = self.get_sales
    shops = { "1": [], "2": [], "3": [], "4": [], "5": [], "6": [], "7": [], "8": [], "9": [] }.as_json
    payload.reject { |x| x["SaleLines"].nil? || x["completed"] == "false" }.map do |s|
      next if s["shopID"] == "0"
      is_multi = s["SaleLines"]["SaleLine"].is_a? Array
      total_cost = s["calcAvgCost"].to_f
      if is_multi
        s["SaleLines"]["SaleLine"].each do |sl|
          item_id = sl["itemID"]
          archived = sl["archived"]
          next if item_id == 0 || item_id == "0" || archived == "true"
          gecko_id = BaseProduct.find_by(light_id: item_id)&.gecko_id
          if gecko_id.nil?
            puts "______________NOT FOUND_______________"
            puts item_id
            puts "______________NOT FOUND_______________"
            next
          end
          is_included = shops[s["shopID"]].find { |x| x["item"] == item_id }
          if is_included.nil?
            payload_2 = {
              quantity: sl["unitQuantity"],
              item: sl["itemID"],
              gecko_id: gecko_id,
              cost: sl["Item"]["defaultCost"]
            }.as_json

            if payload_2["gecko_id"] != "" && payload_2["gecko_id"] != "GECK" && is_included.nil?
              shops[s["shopID"]] << payload_2
            else
              puts "PROBLEM_______________"
              puts sl
              puts "PROBLEM_______________"
            end

          else
            is_included["quantity"] = (is_included["quantity"].to_i + sl["unitQuantity"].to_i).to_s
          end

        end

      else
        item_id = s["SaleLines"]["SaleLine"]["itemID"]
        archived = s["SaleLines"]["SaleLine"]["archived"]
        next if item_id == 0 || item_id == "0" || archived == "true"
        gecko_id = BaseProduct.find_by(light_id: item_id)&.gecko_id
        if gecko_id.nil?
          puts "______________NOT FOUND_______________"
          puts item_id
          puts "______________NOT FOUND_______________"
          next
        end
        if shops[s["shopID"]].nil?
          puts "_________WHAT____________"
          puts s["shopID"]
          puts s
          puts "_________WHAT____________"
        end
        is_included = shops[s["shopID"]].find { |x| x["item"] == item_id }
        payload_2 = {}

        if is_included.nil?
          payload_2 = {
            quantity: s["SaleLines"]["SaleLine"]["unitQuantity"],
            item: s["SaleLines"]["SaleLine"]["itemID"],
            gecko_id: gecko_id,
            cost: s["SaleLines"]["SaleLine"]["Item"]["defaultCost"]
          }.as_json

          if payload_2["gecko_id"] != "" && payload_2["gecko_id"] != "GECK" && is_included.nil?
            shops[s["shopID"]] << payload_2
          else
            puts "PROBLEM_______________"
            puts sl
            puts "PROBLEM_______________"
          end
        else
          is_included["quantity"] = (is_included["quantity"].to_i + s["SaleLines"]["SaleLine"]["unitQuantity"].to_i).to_s
        end
      end
    end

    puts "___________FINAL BUILD___________________________"
    puts shops
    puts "___________FINAL BUILD___________________________"
    shops
  end


end
