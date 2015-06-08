require './ooyala_api.rb'
require 'date'

class AnalyticsToJSON

	def initialize(apiKey, apiSecret)
		@@api_key = apiKey
		@@api_secret = apiSecret
	end

	def apiRequestWithSig(method, uri, pageToken)
		t = Time.now
		query_limit = 500
		expires = Time.local(t.year, t.mon, t.day, t.hour + 1).to_i
		params = { "api_key" => @@api_key, "expires" => expires, "limit" => query_limit}
		if(pageToken != nil)
			params["page_token"] = pageToken
			pageToken = "&page_token=%{ptoken}" % {ptoken: pageToken}
		end
		signature = CGI.escape(OoyalaApi.generate_signature(@@api_secret, method, uri, params, nil))
		getURI = 'http://api.ooyala.com%{uri}?api_key=%{apikey}&expires=%{expires}&limit=%{limit}&signature=%{signature}%{ptoken}' %  { uri: uri, apikey: @@api_key, expires: expires, signature: signature, limit: query_limit, ptoken: pageToken}
		request = RestClient::Request.new(
			:method  => method,
			:url     => getURI
		)
		begin
			response = request.execute
			if response.headers[:x_ratelimit_credits].to_i < 50 then
				puts "%{timestamp} - WARNING - Remaining API credz: %{cred}; will wait for reset in %{reset})" % {timestamp: Time.now, cred: response.headers[:x_ratelimit_credits], reset: response.headers[:x_ratelimit_reset]}
				sleep(response.headers[:x_ratelimit_reset].to_i)
			end
			return response
		rescue RestClient::BadRequest => b
			error = JSON.parse(b.response)
			puts "%{timestamp} - FATAL - Bad API request: %{err}" % {timestamp: Time.now, err: error["message"]}
			puts
			exit(6)
		rescue JSON::ParserError => e
			puts "%{timestamp} - FATAL - Failed to parse server response:" % {timestamp: Time.now}
			puts response
			puts
			exit(5) 
		rescue RestClient::InternalServerError => ise
			puts "%{timestamp} - ERROR - Internal Server Error Received. Will try again in 10 seconds" % {timestamp: Time.now}
			sleep(10)
			retry
		rescue RestClient::ResourceNotFound
			puts "%{timestamp} - ERROR - Resource Not Found. Label %{l_id} does not exist." % {timestamp: Time.now, l_id: label_id}
			exit(10)
		rescue => e
			puts "%{timestamp} - ERROR - Some Error occurred: %{errmsg}. Gathering what we've got before bailing." % {timestamp: Time.now, errmsg: e}
			puts
			puts play_count.to_json
			exit(9)
		end
	end

	# Cheers, Phil.
	def mergeHashes(source_hash, target_hash)
	source_hash.each { |key, value|
	   if target_hash.has_key?(key)
	       target_hash[key] = target_hash[key] + value
	   elsif
	       target_hash[key] = value
	   end
	}
	end

	def getPage(url, pageToken)
		response = apiRequestWithSig("GET", url, pageToken)
		return response
	end

	def hashifyParameterString(param_string)
		param_hash = {}
		param_string.split('&').each do |pair|
			key,value = pair.split('=',2)
			param_hash[key] = value
		end
		return param_hash
	end

	def getPages(url)
		merged_hash = nil
		next_token = nil
		begin
			# Make request, get response
			response = getPage(url, next_token)
			response_hash = JSON.parse(response)
			# Set next_token
			next_url = response_hash["next_page"]
			if(next_url == nil)
				next_token = nil
			else
				next_token = hashifyParameterString(next_url)['page_token']
				puts "Got asset page, getting next page."
			end
			if merged_hash == nil
				merged_hash = response_hash
			else
				mergeHashes(response_hash,merged_hash)
			end
		end until next_token == nil
		return merged_hash
	end

	def getReport(fromDateString, toDateString, outFileName)
		begin
		   fromDate = Date.parse(fromDateString)
		rescue ArgumentError
		   puts "Start Date is not a valid ISO date. Use the format yyyy-mm-dd, e.g. 2014-10-17"
		   exit(2)
		end
		begin
		   toDate = Date.parse(toDateString)
		rescue ArgumentError
		   puts "End Date is not a valid ISO date. Use the format yyyy-mm-dd, e.g. 2014-10-17"
		   exit(2)
		end
		if outFileName == nil
			outFileName = "analytics_results.json"
		end
		# If customer wants stats between day X and day Y, we need to set an end date of Y+1. Our analytics are quirky.
		url = "/v2/analytics/reports/account/performance/videos/%{from}...%{to}" % { from: fromDate.to_s, to: (toDate+1).to_s }
		json_hash = getPages(url)
		File.open(outFileName, "w") do |outfile|
			outfile.write(JSON.pretty_generate(json_hash))
			outfile.close
		end
	end
end