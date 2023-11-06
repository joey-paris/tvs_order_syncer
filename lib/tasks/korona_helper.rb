require "httparty"
module KoronaHelper
  def apiGet(url)
    user = 'admin'
    password = "password"
    korona_headers = {
      'Authorization': "Basic #{Base64::encode64("#{user}:#{password}")}",
      "Content-Type": "application/json"
    }
    res=HTTParty.get(url, headers: korona_headers).parsed_response
    if res
      return res
    else
      puts "get api request fails", res
      return nil
    end
  end
  def apiDel(url)
    user = 'admin'
    password = "password"
    korona_headers = {
      'Authorization': "Basic #{Base64::encode64("#{user}:#{password}")}",
      "Content-Type": "application/json"
    }
    res=HTTParty.delete(url, headers: korona_headers).code
    if res == 204
      return res
    else
      puts "delete api request fails", res
      return nil
    end
  end

  def apiPost(url, body)
    res = HTTParty.post(url, headers: { "Content-Type": "application/json" }, body: body).parsed_response
    if res
      puts "payload sent successfully"
      return res
    else
      puts "hook post api request fails", res
      return nil
    end
  end

  def create_k_product(params)
    payload = []
    koronaAccountId = "bb26d9a6-3cdd-4c90-bc1c-384387f39783"
    user = 'admin'
    password = "password"
    korona_headers = {
        'Authorization': "Basic #{Base64::encode64("#{user}:#{password}")}",
        "Content-Type": "application/json"
    }
    # {"id"=>"004b6841-fd04-4478-ac74-f457927c3b92", "name"=>"Beamer Chong Tray Beamer Chong Tray", "codes"=>[{"productCode"=>"615068009737", "containerSize"=>1.0}], "costs"=>0.0, "active"=>true, "listed"=>true, "number"=>"210000000322", "prices"=>[{"value"=>7.99, "validFrom"=>"2023-07-20T03:00:00-04:00", "priceGroup"=>{"id"=>"7c1991dd-be5d-4332-83f4-5ecc91a5e92a", "name"=>"Default", "number"=>"1"}}], "sector"=>{"id"=>"074452ce-77c3-42c8-a429-643cc3e78283", "name"=>"General", "number"=>"1"}, "deposit"=>false, "maxPrice"=>9999.99, "minPrice"=>-9999.99, "revision"=>73403, "salesLock"=>false, "assortment"=>{"id"=>"cbec8c76-e29d-403a-b7b9-93975a3045f5", "name"=>"General Assortment", "number"=>"1"}, "conversion"=>false, "deactivated"=>false, "listedSince"=>"2023-07-20T15:38:16-04:00", "discountable"=>true, "commodityGroup"=>{"id"=>"2fdccaf5-4d03-4c33-ae42-cc637f2381c6", "name"=>"Rolling Trays", "number"=>"16"}, "priceChangable"=>false, "supplierPrices"=>[{"value"=>3.75, "supplier"=>{"id"=>"404d54f3-4c42-4d31-a8d3-48ab69da83ac", "name"=>"TVS Distributors", "number"=>"1"}, "orderCode"=>"TVS262", "containerSize"=>1.0}], "trackInventory"=>true, "lastPurchasePrice"=>3.75, "packagingRequired"=>false, "serialNumberRequired"=>false, "stockReturnUnsellable"=>false, "printTicketsSeparately"=>true, "subproductPresentation"=>"DEFAULT", "personalizationRequired"=>false, "independentSubarticleDiscounts"=>false} 
    payload << {
      "name": params[:name],
      "costs": params[:wholesale_cost],
      "codes": [{"productCode": params[:upc], "containerSize": 1.0}],
      "maxPrice": 9999.99,
      "minPrice": -9999.99,
      "discountable": true,
      "trackInventory": true,
      "supplierPrices": [{"value": params[:price], "supplier": {"name": "TVS Distributors", "number": "1"}, "orderCode": params[:sku], "containerSize": 1.0}],
      "prices": [{"value": params[:price], "validFrom": Time.now.strftime("%Y-%m-%dT%H:%M:%S%:z"), "priceGroup": {"name": "Default", "number": "1"}}],
      "commodityGroup": {"name": "Rolling Trays", "number": "16"},
      "sector": {"name": "General", "number": "1"},
      "assortment": {"name": "General Assortment", "number": "1"}
    }
    # payload << {
    #   "name": params[:name],
    #   "defaultCost": params[:wholesale_cost],
    #   "manufacturerSku": params[:upc],
    #   "customSku": params[:sku],
    #   "Prices": {
    #     "ItemPrice": [
    #         {
    #           "amount": params[:cost],
    #           "useTypeID": "1",
    #           "useType": "Default"
    #         }
    #       ]
    #     },
    #     "CustomFieldValues": {
    #     "CustomFieldValue": {
    #        "customFieldID": "1",
    #        "value": params[:shopify_variant_id]
    #       }
    #     }
    # }
    url = "https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/products?writeMode=ADD_OR_UPDATE"
    res = HTTParty.post(url, headers: korona_headers, body: JSON.dump(payload)).parsed_response
    if res
        puts "Store order Product created successfully"
        return res
    else
        puts "STORE ORDER create product api request fails", res
        return nil
    end
  end

  def delete_k_product(params)
    # bulk
    productId = params[:id]
    koronaAccountId = "bb26d9a6-3cdd-4c90-bc1c-384387f39783"
    user = 'admin'
    password = "password"
    korona_headers = {
        'Authorization': "Basic #{Base64::encode64("#{user}:#{password}")}",
        "Content-Type": "application/json"
    }
    url = "https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/products/#{productId}"
    res = HTTParty.delete(url, headers: korona_headers).parsed_response
    if res
        puts "Store order Product deleted successfully"
        return res
    else
        puts "STORE ORDER delete product api request fails", res
        return nil
    end
  end

end
