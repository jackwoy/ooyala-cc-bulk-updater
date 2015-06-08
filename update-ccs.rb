OUTPUT_FOLDER='./output'
VERIFY_FOLDER='./output'

if !Dir.exist?(OUTPUT_FOLDER)
	puts 'Could not find output folder. Creating it now.'
	Dir.mkdir(OUTPUT_FOLDER)
end

# Get list of filenames in directory
# Iterate over filenames
Dir["./output/18147/*.xml"].each do |cc_file|
	current_text = File.read(cc_file).force_encoding('UTF-8')

	puts cc_file
	replace = false
	verify = false
	fontsize_count = current_text.scan(/tts:fontSize="\w+"/).count
	if(fontsize_count > 1)
		puts "Warning. file %{f} has %{c} fontsize declarations." % {f: File.basename(cc_file), c: fontsize_count}
		verify = true
	end
	plus_sign_count = current_text.scan(/tts:fontSize="\+\w+"/).count
	if(plus_sign_count > 0)
		puts "Warning. file %{f} uses plus sign." % {f: File.basename(cc_file)}
		replace = true
	end

	if (verify && replace)
		new_filename = "%{of}/%{f}" % {of: VERIFY_FOLDER, f: File.basename(cc_file)}
		File.open(new_filename, "w") {|file| file.puts current_text}
	elsif (replace && !verify)
		new_filename = "%{of}/%{f}" % {of: OUTPUT_FOLDER, f: File.basename(cc_file)}
		new_text = current_text.gsub(/tts:fontSize="\+\w+"/, "tts:fontSize=\"16px\"")
		File.open(new_filename, "w") {|file| file.puts new_text}
	end
	
end