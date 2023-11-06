require 'uri'
class ShopifyApi < ApplicationRecord
  include HTTParty

  def headers
     {
       'Content-Type': 'application/json',
       'X-Shopify-Access-Token': auth_key
     }
  end

  def product(params)
    self.class.get("https://sdinland10.myshopify.com/admin/api/2022-04/products/#{params[:id]}.json", headers: headers).parsed_response
  end

  def customers
    self.class.get("https://sdinland10.myshopify.com/admin/api/2022-04/customers.json", headers: headers).parsed_response
  end

  def variant(params)
    self.class.get("https://sdinland10.myshopify.com/admin/api/2022-04/variants/#{params[:id]}.json", headers: headers).parsed_response
  end

  def inventory_item(params)
    self.class.get("https://sdinland10.myshopify.com/admin/api/2022-04/inventory_items/#{params[:id]}.json", headers: headers).parsed_response
  end

  def get_products_id(params)
    products = self.class.get("https://sdinland10.myshopify.com/admin/api/2022-04/products.json?ids=#{params[:ids].join("%2C")}", headers: headers).parsed_response
    mapped = products["products"].map do |x|
      vars = x["variants"].map do |g|
        g.merge({ product_name: x["title"] }.as_json)
      end

      vars
    end.flatten

    mapped
  end

  def find_shop(params)
  shops = [
    {:name=>"TVS - Rochester", :shop_id=>"1", :t_id => "5502310842420"},
    {:name=>"TVS - DEQ", :shop_id=>"2", :t_id => "5502310613044"},
    {:name=>"TVS - Gratiot", :shop_id=>"3", :t_id => "5502310678580"},
    {:name=>"TVS - Clinton", :shop_id=>"4", :t_id => "5502310547508"},
    {:name=>"TVS - Crooks", :shop_id=>"5", :t_id => "5502310580276"},
    {:name=>"TVS - Shelby", :shop_id=>"6", :t_id => "5502310875188"},
    {:name=>"TVS - Woodward", :shop_id=>"7", :t_id => "5502310645812"},
    {:name=>"TVS - Chesterfield", :shop_id=>"8", :t_id => "5502310514740"},
    {:name=>"TVS - Orchard Lake", :shop_id=>"9", :t_id => "5502310809652"},
    {:name=>"TVS - Madison", :shop_id=>"16", :t_id => "5502310711348"},
    {:name=>"TVS - Novi", :shop_id=>"17", :t_id => "5502310776884"},
    {:name=> "TVS - Rochester Hills", :shop_id=>"18", :t_id=>"5558680846388"}
  ]
  shops.find { |x| params[:shop_id].to_s == x[:shop_id] }
end

def products_by_id(params)
  # one of the dumbest endpoint pagination workflows. Need to use header link, you have no idea
  # how many pages there are so you just keep plucking out the link from the headers until
  # there isn't a next link for you to use...sweet.
  final = false
  pages = []
  products = []
  params[:ids].in_groups_of(100) do |grp|
    res = self.class.get("https://sdinland10.myshopify.com/admin/api/2022-04/products.json?limit=250&ids=#{grp.join("%2C")}", headers: headers)
    header_val = ''
    page_link = ''
    direction = ''
    page = 1
    products.concat(res.parsed_response["products"])
    # if there is a next page
    if res.headers["link"]
      header_val = res.headers["link"]
      page_link = header_val.split('; ')[0].gsub("<", "").gsub(">", "")
      direction = header_val.split("; ")[1].split("=")[1].include?("next") ? 'next' : 'previous'
      while !final
        res_2 = self.class.get(page_link, headers: headers)
        header_val = res_2.headers["link"].split(", ")
        products.concat(res_2["products"])
        is_next = header_val.any? { |x| x.split("; ")[1].split("=")[1].include?("next") }
        if !is_next
          final = true
          break
        end
        header_val.select { |x| x.split("; ")[1].split("=")[1].include?("next") }.each do |x|
          page_link = x.split('; ')[0].gsub("<", "").gsub(">", "")
          direction = x.split("; ")[1].split("=")[1].include?("next") ? 'next' : 'previous'
          pages << { page_link: page_link, direction: direction, page: page }.as_json
        end
        page += 1
      end
    end
  end
  mapped = products.map do |x|
    vars = x["variants"].map do |g|
      g.merge({ product_name: x["title"] }.as_json)
    end

    vars
  end.flatten

  mapped
end

def gen_product_payload
  variants = []
  inventory_items = []
  products = self.products
  products.each do |p|
    mapped_vars = p["variants"].map do |z|
      z["product_title"] = p['title']
      z
    end
    variants.concat(mapped_vars)
  end
  variants.in_groups_of(100, false) do |group|
    inv_items = self.inventory_items(ids: group.pluck("inventory_item_id").join("%2C"))
    inventory_items.concat(inv_items)
  end
  mapped_vars = variants.map do |v|
    v["cost"] = inventory_items.find { |x| x['id'] == v['inventory_item_id'] }.dig("cost")

    v
  end
  mapped_vars
end

  def products
    # one of the dumbest endpoint pagination workflows. Need to use header link, you have no idea
    # how many pages there are so you just keep plucking out the link from the headers until
    # there isn't a next link for you to use...sweet.
    final = false
    pages = []
    products = []
    res = self.class.get('https://sdinland10.myshopify.com/admin/api/2022-04/products.json?limit=250', headers: headers)
    header_val = ''
    page_link = ''
    direction = ''
    page = 1
    products.concat(res.parsed_response["products"])
    # if there is a next page
    if res.headers["link"]
      header_val = res.headers["link"]
      page_link = header_val.split('; ')[0].gsub("<", "").gsub(">", "")
      direction = header_val.split("; ")[1].split("=")[1].include?("next") ? 'next' : 'previous'
      while !final
        res_2 = self.class.get(page_link, headers: headers)
        header_val = res_2.headers["link"].split(", ")
        products.concat(res_2["products"])
        is_next = header_val.any? { |x| x.split("; ")[1].split("=")[1].include?("next") }
        if !is_next
          final = true
          break
        end
        header_val.select { |x| x.split("; ")[1].split("=")[1].include?("next") }.each do |x|
          page_link = x.split('; ')[0].gsub("<", "").gsub(">", "")
          direction = x.split("; ")[1].split("=")[1].include?("next") ? 'next' : 'previous'
          pages << { page_link: page_link, direction: direction, page: page }.as_json
        end
        page += 1
      end
    end
    products
  end

  def inventory_items(params)
    # one of the dumbest endpoint pagination workflows. Need to use header link, you have no idea
    # how many pages there are so you just keep plucking out the link from the headers until
    # there isn't a next link for you to use...sweet.
    final = false
    pages = []
    products = []
    res = self.class.get("https://sdinland10.myshopify.com/admin/api/2022-04/inventory_items.json?limit=250&ids=#{params[:ids]}", headers: headers)
    header_val = ''
    page_link = ''
    direction = ''
    page = 1
    if res['errors']
      sleep 2
      res = self.class.get("https://sdinland10.myshopify.com/admin/api/2022-04/inventory_items.json?limit=250&ids=#{params[:ids]}", headers: headers)
    end
    products.concat(res.parsed_response["inventory_items"])
    # if there is a next page
    if res.headers["link"]
      header_val = res.headers["link"]
      page_link = header_val.split('; ')[0].gsub("<", "").gsub(">", "")
      direction = header_val.split("; ")[1].split("=")[1].include?("next") ? 'next' : 'previous'
      while !final
        sleep 1
        res_2 = self.class.get(page_link, headers: headers)
        header_val = res_2.headers["link"].split(", ")
        products.concat(res_2["inventory_items"])
        is_next = header_val.any? { |x| x.split("; ")[1].split("=")[1].include?("next") }
        if !is_next
          final = true
          break
        end
        header_val.select { |x| x.split("; ")[1].split("=")[1].include?("next") }.each do |x|
          page_link = x.split('; ')[0].gsub("<", "").gsub(">", "")
          direction = x.split("; ")[1].split("=")[1].include?("next") ? 'next' : 'previous'
          pages << { page_link: page_link, direction: direction, page: page }.as_json
        end
        page += 1
      end
    end
    products
  end

  def orders
  end

  def create_order(params)
    payload = {
      "order": {
        "line_items": params[:lines],
        "customer": { "id": params[:customer_id].to_i }
      }
    }
    self.class.post('https://sdinland10.myshopify.com/admin/api/2022-04/orders.json', body: JSON.dump(payload), headers: headers).parsed_response
  end

  def generate_ls_product
  end

  def from_ls
  end

  def hooks
    res = self.class.get('https://sdinland10.myshopify.com/admin/api/2022-04/webhooks.json', headers: headers)
    res.parsed_response
  end

  def create_hook(params)
    payload = {
      "webhook": {
        "topic": params[:action],
        "address": params[:url],
        "format": "json"
      }
    }
    self.class.post('https://sdinland10.myshopify.com/admin/api/2022-04/webhooks.json', body: JSON.dump(payload), headers: headers).parsed_response
  end
end
