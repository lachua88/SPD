require 'sinatra'

#####
# Reporting Routes
#####

config_options = JSON.parse(File.read('./config.json'))

# List current reports
get '/reports/list' do
    @reports = get_reports

    @admin = true if is_administrator?

	# allow the user to set their logo in the configuration options
	@logo = config_options["logo"]

    haml :reports_list, :encode_html => true
end

# Create a report
get '/report/new' do
    @templates = Xslt.all
    haml :new_report, :encode_html => true
end

# Create a report
post '/report/new' do
    data = url_escape_hash(request.POST)

    data["owner"] = get_username
    data["date"] = DateTime.now.strftime "%m/%d/%Y"

    @report = Reports.new(data)
    @report.save

    redirect to("/report/#{@report.id}/edit")
end

#Delete a report
get '/report/:id/remove' do
    id = params[:id]

    # Query for the first report matching the id
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    # get all findings associated with the report
    @findings = Findings.all(:report_id => id)

    # delete the entries
    @findings.destroy
    @report.destroy

    redirect to("/reports/list")
end

# Edit the Report's main information; Name, Consultant, etc.
get '/report/:id/edit' do
    id = params[:id]

    # Query for the first report matching the report_name
    @report = get_report(id)
	@templates = Xslt.all(:order => [:report_type.asc])

    if @report == nil
        return "No Such Report"
    end

    haml :report_edit, :encode_html => true
end

# Edit the Report's main information; Name, Consultant, etc.
get '/report/:id/additional_features' do
    id = params[:id]

    # Query for the first report matching the report_name
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    haml :additional_features, :encode_html => true
end


# Edit a report
post '/report/:id/edit' do
    id = params[:id]

    data = url_escape_hash(request.POST)

    @report = get_report(id)
    @report = @report.update(data)

    redirect to("/report/#{id}/edit")
end

#Edit user defined variables
get '/report/:id/user_defined_variables' do
    id = params[:id]
    @report = get_report(id)

    if  @report.user_defined_variables
        @user_variables = JSON.parse(@report.user_defined_variables)

        # add in the global UDV from config
        if config_options["user_defined_variables"].size > 0 and !@user_variables.include?(config_options["user_defined_variables"][0])
            @user_variables = @user_variables + config_options["user_defined_variables"]
        end

        @user_variables.each do |k,v|
			if v
				@user_variables[k] = meta_markup(v)
			end
        end
    else
        @user_variables = config_options["user_defined_variables"]
    end

    haml :user_defined_variable, :encode_html => true
end

#Post user defined variables
post '/report/:id/user_defined_variables' do
    data = url_escape_hash(request.POST)

	variable_hash = Hash.new()
	data.each do |k,v|
		if k =~ /variable_name/
			key = k.split("variable_name_").last.split("_").first

			# remove certain elements from name %&"<>
			v = v.gsub("%","_").gsub("&quot;","'").gsub("&amp;","").gsub("&gt;","").gsub("&lt;","")
			variable_hash["#{key}%#{v}"] = "DEFAULT"

		end
		if k =~ /variable_data/
			key = k.split("variable_data_").last.split("_").first

			variable_hash.each do |k1,v1|
				if k1 =~ /%/
					kk = k1.split("%")
					if kk.first == key
						variable_hash[k1] = v
					end
				end
			end
		end
	end

	# remove the % and any blank values
	q = variable_hash.clone
	variable_hash.each do |k,v|
		if k =~ /%/
			p k.split("%")
			if k.split("%").size == 1
				q.delete(k)
			else
				q[k.split("%").last] = v
				q.delete(k)
			end
		end
	end
	variable_hash = q

    id = params[:id]
    @report = get_report(id)

    @report.user_defined_variables = variable_hash.to_json
    @report.save
    redirect to("/report/#{id}/user_defined_variables")

end