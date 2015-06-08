require './analyticstojson.rb'
require 'json'
require 'open-uri'

API_KEY="KEY_GOES_HERE"
SECRET="SECRET_GOES_HERE"
OUTPUT_FOLDER='./output'

=begin

- Get first n (500?) assets in user account
- Parse JSON to hash
- Get next n...
- Until we don't see the next page token any more.
- For each embed code with a CC URL in the hash, download the CC file. Ensure it is named according to the embed code for the asset.
=end

if !Dir.exist?(OUTPUT_FOLDER)
  puts 'Could not find output folder. Creating it now.'
  Dir.mkdir(OUTPUT_FOLDER)
end

hashgrabber = AnalyticsToJSON.new(API_KEY,SECRET)
puts "Getting asset hash."
data_hash = hashgrabber.getPages('/v2/assets')
puts "Asset hash with %{count} assets acquired, downloading CC files." % {count: data_hash['items'].count}

asset_counter = 0
assets_with_cc_counter = 0

data_hash['items'].each do |asset|
	if(asset.has_key?("closed_captions_url"))
		ec = asset.fetch("embed_code")
		cc = asset.fetch("closed_captions_url")
		filename = '%{output}/%{embed}.xml' % {output: OUTPUT_FOLDER, embed: ec}
		#puts "Found closed captions for embed code %{embed}. Downloading." % {embed: ec}
		open(filename, 'wb') do |file|
			begin
				file << open(cc).read
			rescue => e
				puts "%{timestamp} - ERROR - Some Error occurred: %{errmsg}." % {timestamp: Time.now, errmsg: e}
				puts
				puts ec
				puts cc
			end
		end
		assets_with_cc_counter = assets_with_cc_counter + 1
	end
	asset_counter = asset_counter + 1
	if (asset_counter % 50 == 0)
		puts "Processed %{assets} assets, found %{cc_assets} with closed captions." % {assets: asset_counter, cc_assets: assets_with_cc_counter}
	end
end