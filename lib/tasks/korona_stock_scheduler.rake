# https://167.koronacloud.com/web/?locale=en#!storeorder_list-%3Estoreordertemplate_list
# https://167.koronacloud.com
# korona = KoronaApi.new(
#   client_id: "bbe3e974cedb7170e6197317cdbdde61715202c31ead8818cd5f65e8261efdfa",
#   client_secret: "d5d7597124cbe2feb44ba730a0d96745ef8ae06f65b241dd37d29794dbd86e26",
#   refresh: '9fb70dd890071cb799bd3811eaeba3315119f6eb',
#   korona_key: '37dd710765077812ae7c579e4b493f56dba2b3d0',
#   account: '240034'
# )
# korona.save!
# auth = korona.authorize(code: "753f684c3991e9cce58e4bed957a19db866bd98f")
# binding.pry
# end

# def refresh_token
#   payload = {
#     'refresh_token': refresh,
#     'client_secret': client_secret,
#     'client_id': client_id,
#     'grant_type': 'refresh_token',
#   }
#   res = self.class.post('https://167.koronacloud.com/oauth/access_token.php', body: payload).parsed_response
#   if res["httpCode"]
#     sleep 5
#     res = self.class.post('/oauth/access_token.php', body: payload).parsed_response
#   end
#   @light_key = res["access_token"]
#   self.update!(light_key: @light_key)
#   res
# end

require 'httparty'
require "base64"
desc "stock orders from korona."
task :stock_order => :environment do
  include HTTParty
    koronaAccountId = "bb26d9a6-3cdd-4c90-bc1c-384387f39783"
    
    # HTTParty.get('')
    user = 'admin'
    password = "password"
    korona_headers = {
      'Authorization': "Basic #{Base64::encode64("#{user}:#{password}")}",
      "Content-Type": "application/json"
    }
    base_product = BaseProduct.all
    res = self.class.get("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/stockOrders", headers: korona_headers).parsed_response
    sid = self.class.put("https://167.koronacloud.com/web/api/v3/accounts/#{koronaAccountId}/stockOrders/15d20034-1f59-44c7-b28f-2c1a76a841cb", headers: korona_headers).parsed_response
    # loop on res["results"], then look for ["items"] and get ["productCode"] with loop
    stock = res["results"]
    # code = stock[1]["items"][0]["productCode"]
    stock.each do |i|
      stockOrderId = i["id"]
      item = i["items"]
      item.each do |j|
        korona_product = j[0]
        k_product_code = korona_product["productCode"]
        matched_product = base_product.where(:sku == code)
        if matched_product.exists?

        else
        end
        byebug
        # base_product.find_by(sku: k_product_code)

      end
    end
    # /web/api/v3/accounts/{koronaAccountId}/stockOrders/{stockOrderId}
    # BaseProduct.find_by()
  end
