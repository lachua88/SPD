require 'sinatra'
require 'zip'

######
# Admin Interfaces
######

# Manage Templated Reports
get '/admin/templates' do
    redirect to("/no_access") if not is_administrator?

    @admin = true

    # Query for all Findings
    @templates = Xslt.all(:order => [:report_type.asc])

    haml :template_list, :encode_html => true
end

# Manage Templated Reports
get '/admin/templates/add' do
    redirect to("/no_access") if not is_administrator?

    @admin = true

    haml :add_template, :encode_html => true
end

# Manage Templated Reports
get '/admin/templates/:id/download' do
    redirect to("/no_access") if not is_administrator?

    @admin = true

    xslt = Xslt.first(:id => params[:id])

    send_file xslt.docx_location, :type => 'docx', :filename => "#{xslt.report_type}.docx"
end

get '/admin/delete/templates/:id' do
    redirect to("/no_access") if not is_administrator?

    @xslt = Xslt.first(:id => params[:id])

	if @xslt
		@xslt.destroy
		File.delete(@xslt.xslt_location)
		File.delete(@xslt.docx_location)
	end
    redirect to('/admin/templates')
end


# Manage Templated Reports
post '/admin/templates/add' do
    redirect to("/no_access") if not is_administrator?

    @admin = true

	xslt_file = "./templates/#{rand(36**36).to_s(36)}.xslt"

    redirect to("/admin/templates/add") unless params[:file]

	# reject if the file is above a certain limit
	if params[:file][:tempfile].size > 100000000
		return "File too large. 10MB limit"
	end

	docx = "./templates/#{rand(36**36).to_s(36)}.docx"
	File.open(docx, 'wb') {|f| f.write(params[:file][:tempfile].read) }

    error = false
    detail = ""
    begin
	    xslt = generate_xslt(docx)
    rescue ReportingError => detail
        error = true
    end


    if error
        "The report template you uploaded threw an error when parsing:<p><p> #{detail.errorString}"
    else

    	# open up a file handle and write the attachment
	    File.open(xslt_file, 'wb') {|f| f.write(xslt) }

	    # delete the file data from the attachment
	    datax = Hash.new
	    # to prevent traversal we hardcode this
	    datax["docx_location"] = "#{docx}"
	    datax["xslt_location"] = "#{xslt_file}"
	    datax["description"] = 	params[:description]
	    datax["report_type"] = params[:report_type]
	    data = url_escape_hash(datax)
	    data["finding_template"] = params[:finding_template] ? true : false
	    data["status_template"] = params[:status_template] ? true : false

	    @current = Xslt.first(:report_type => data["report_type"])

	    if @current
		    @current.update(:xslt_location => data["xslt_location"], :docx_location => data["docx_location"], :description => data["description"])
	    else
		    @template = Xslt.new(data)
		    @template.save
	    end

	    redirect to("/admin/templates")

        haml :add_template, :encode_html => true
    end
end

# Manage Templated Reports
get '/admin/templates/:id/edit' do
    redirect to("/no_access") if not is_administrator?

    @admind = true
    @template = Xslt.first(:id => params[:id])

    haml :edit_template, :encode_html => true
end

# Manage Templated Reports
post '/admin/templates/edit' do
    redirect to("/no_access") if not is_administrator?

    @admin = true
    template = Xslt.first(:id => params[:id])

    xslt_file = template.xslt_location

    redirect to("/admin/templates/#{params[:id]}/edit") unless params[:file]

    # reject if the file is above a certain limit
    if params[:file][:tempfile].size > 100000000
        return "File too large. 10MB limit"
    end

    docx = "./templates/#{rand(36**36).to_s(36)}.docx"
    File.open(docx, 'wb') {|f| f.write(params[:file][:tempfile].read) }

    error = false
    detail = ""
    begin
	    xslt = generate_xslt(docx)
    rescue ReportingError => detail
        error = true
    end

    if error
        "The report template you uploaded threw an error when parsing:<p><p> #{detail.errorString}"
    else

    	# open up a file handle and write the attachment
	    File.open(xslt_file, 'wb') {|f| f.write(xslt) }

	    # delete the file data from the attachment
	    datax = Hash.new
	    # to prevent traversal we hardcode this
	    datax["docx_location"] = "#{docx}"
	    datax["xslt_location"] = "#{xslt_file}"
	    datax["description"] = 	params[:description]
	    datax["report_type"] = params[:report_type]
	    data = url_escape_hash(datax)
	    data["finding_template"] = params[:finding_template] ? true : false
	    data["status_template"] = params[:status_template] ? true : false

	    @current = Xslt.first(:report_type => data["report_type"])

	    if @current
		    @current.update(:xslt_location => data["xslt_location"], :docx_location => data["docx_location"], :description => data["description"])
	    else
		    @template = Xslt.new(data)
		    @template.save
	    end

	    redirect to("/admin/templates")
    end
end