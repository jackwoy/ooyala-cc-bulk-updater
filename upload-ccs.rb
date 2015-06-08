require './ooyala_api_v2.rb'

API_KEY="KEY_GOES_HERE"
SECRET="SECRET_GOES_HERE"
OUTPUT_FOLDER='./output'

api = Ooyala::API.new(API_KEY, SECRET)

Dir["./output/*.xml"].each do |cc_file|
	body = File.read(cc_file)
	embed_code = File.basename(cc_file).gsub(/.xml/,"")
	api_path = '/v2/assets/%{ec}/closed_captions' % {ec: embed_code}
	api.put(api_path, body)
	puts "Uploaded new CCs for %{ec}" % {ec: embed_code}
end