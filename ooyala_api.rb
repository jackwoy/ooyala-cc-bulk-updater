require "digest/sha2"
require "base64"
require "json"
require "rest-client"


module OoyalaApi

  def self.generate_signature(secret, http_method, request_path, query_string_params, request_body)
    string_to_sign = secret + http_method + request_path
    sorted_query_string = query_string_params.sort { |pair1, pair2| pair1[0] <=> pair2[0] }
    string_to_sign += sorted_query_string.map { |key, value| "#{key}=#{value}"}.join
    string_to_sign += request_body.to_s
    signature = Base64::encode64(Digest::SHA256.digest(string_to_sign))[0..42].chomp("=")
    if $options && $options[:verbose]
      puts "String to sign: %{sts}" % {sts: string_to_sign}
      puts "Signature: %{sig}" % {sig: signature}
    end
    return signature
  end

  def self.sendPost(api_path, json, creds)
    t = Time.now
    expires = Time.local(t.year, t.mon, t.day, t.hour + 1).to_i
    params = { "api_key" => creds["key"], "expires" => expires }
    signature = CGI.escape(OoyalaApi.generate_signature(creds["secret"], "POST", api_path, params, json))

    postURI = 'http://api.ooyala.com%{path}?api_key=%{apikey}&expires=%{expires}&signature=%{signature}' %  {path: api_path, apikey: creds["key"], expires: expires, signature: signature}
    if $options && $options[:verbose]
      puts "Posting to URI:"
      puts postURI
      puts
    end

    request = RestClient::Request.new(
      :method  => "POST",
      :url     => postURI,
      :payload => json
    )

    begin
      response = request.execute
      json_response = JSON.parse(response)
    rescue JSON::ParserError => e
      puts "  Error: Failed to parse server response:"
      puts response
      puts
    rescue RestClient::BadRequest => b
      error = JSON.parse(b.response)
      puts "   Error: Bad API request: %{err}" % {err: error["message"]}
      puts
      exit(6)
    end

    if $options[:verbose]
      puts "Server response:"
      puts json_response
      puts
    end

    return json_response
  end

  def self.sendGet(api_path, creds)
    t = Time.now
    expires = Time.local(t.year, t.mon, t.day, t.hour + 1).to_i
    params = { "api_key" => creds["key"], "expires" => expires }
    signature = CGI.escape(OoyalaApi.generate_signature(creds["secret"], "GET", api_path, params, nil))

    getURI = 'http://api.ooyala.com%{path}?api_key=%{apikey}&expires=%{expires}&signature=%{signature}' %  {path: api_path, apikey: creds["key"], expires: expires, signature: signature}

    if $options[:verbose]
      puts "Requesting from URI:"
      puts getURI
      puts
    end
   
    request = RestClient::Request.new(
      :method  => "GET",
      :url     => getURI
    )

    begin
      response = request.execute
      json_response = JSON.parse(response)
    rescue RestClient::BadRequest => b
      error = JSON.parse(b.response)
      puts "   Fatal: Bad API request: %{err}" % {err: error["message"]}
      puts
      exit(6)
    rescue JSON::ParserError => e
      puts "  Error: Failed to parse server response:"
      puts response
      puts
      exit(5) 
    end

    if $options[:verbose]
      puts "Server response:"
      puts json_response
      puts
    end

    return json_response

  end

end
