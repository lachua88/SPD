require 'sinatra'

#####
# Reporting Routes
#####

config_options = JSON.parse(File.read('./config.json'))


# List attachments
get '/report/:id/attachments' do
    id = params[:id]

    # Query for the first report matching the id
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    @attachments = Attachments.all(:report_id => id)
    haml :list_attachments, :encode_html => true
end

get '/report/:id/export_attachments' do
    id = params[:id]
    rand_zip = "./tmp/#{rand(36**12).to_s(36)}.zip"
    @attachments = Attachments.all(:report_id => id)

    Zip::File.open(rand_zip, Zip::File::CREATE) do |zipfile|
      @attachments.each do | attachment|
       zipfile.add(attachment.filename_location.gsub("./attachments/",""), attachment.filename_location )
     end
    end

    send_file rand_zip, :type => 'zip', :filename => "attachments.zip"
    #File.delete(rand_zip) should the temp file be deleted?
end

# Restore Attachments menu
get '/report/:id/restore_attachments' do
  haml :restore_attachments, :encode_html => true
end

post '/report/:id/restore_attachments' do
  id = params["id"]
  #Not sure this is the best way to do this.
  rand_zip = "./tmp/#{rand(36**12).to_s(36)}.zip"
  File.open(rand_zip, 'wb') {|f| f.write(params[:file][:tempfile].read) }
  begin
    Zip::File.open(rand_zip) do |file|
      n = file.num_files
      n.times do |i|
        entry_name = file.get_name(i)
        file.fopen(entry_name) do |f|
          clean_name = f.name.split(".")[0]
          File.open("./attachments/#{clean_name}", "wb") do |data|
            data << f.read
          end
        end
      end
    end
  rescue
    puts "Not a Zip file. Please try again"
  end
  #File.delete(rand_zip) should the temp file be deleted?
  redirect to("/report/#{id}/edit")
end

# Upload attachment menu
get '/report/:id/upload_attachments' do
    id = params[:id]
    @no_file = params[:no_file]

    # Query for the first report matching the id
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    @attachments = Attachments.all(:report_id => id)

    haml :upload_attachments, :encode_html => true
end

post '/report/:id/upload_attachments' do
    id = params[:id]

    # Query for the first report matching the id
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    if params[:files] == nil
    	redirect to("/report/#{id}/upload_attachments?no_file=1")
    end

    params['files'].map{ |upf|
        # We use a random filename
        rand_file = "./attachments/#{rand(36**36).to_s(36)}"

    	# reject if the file is above a certain limit
    	if upf[:tempfile].size > 100000000
    		return "File too large. 100MB limit"
    	end

    	# open up a file handle and write the attachment
    	File.open(rand_file, 'wb') {|f| f.write(upf[:tempfile].read) }

    	# delete the file data from the attachment
    	datax = Hash.new
    	# to prevent traversal we hardcode this
    	datax["filename_location"] = "#{rand_file}"
    	datax["filename"] = upf[:filename]
    	datax["description"] = CGI::escapeHTML(upf[:filename]).gsub(" ","_").gsub("/","_").gsub("\\","_").gsub("`","_")
    	datax["report_id"] = id
    	data = url_escape_hash(datax)

    	@attachment = Attachments.new(data)
    	@attachment.save
    }
	redirect to("/report/#{id}/attachments")
end

get '/report/:id/export_attachments' do
    id = params[:id]
    rand_zip = "./tmp/#{rand(36**12).to_s(36)}.zip"
    @attachments = Attachments.all(:report_id => id)

    Zip::File.open(rand_zip, Zip::File::CREATE) do |zipfile|
      @attachments.each do | attachment|
       zipfile.add(attachment.filename_location.gsub("./attachments/",""), attachment.filename_location )
     end
    end

    send_file rand_zip, :type => 'zip', :filename => "attachments.zip"
    #File.delete(rand_zip) should the temp file be deleted?
end

# display attachment
get '/report/:id/attachments/:att_id' do
    id = params[:id]

    # Query for the first report matching the id
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    @attachment = Attachments.first(:report_id => id, :id => params[:att_id])
    send_file @attachment.filename_location, :filename => "#{@attachment.filename}"
end

#Delete an attachment
get '/report/:id/attachments/delete/:att_id' do
    id = params[:id]

    # Query for the first report matching the id
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    @attachment = Attachments.first(:report_id => id, :id => params[:att_id])

	if @attachment == nil
		return "No Such Attachment"
	end

    File.delete(@attachment.filename_location)

    # delete the entries
    @attachment.destroy

	redirect to("/report/#{id}/attachments")
end