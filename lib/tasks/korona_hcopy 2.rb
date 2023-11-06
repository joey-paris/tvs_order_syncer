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
  
end
