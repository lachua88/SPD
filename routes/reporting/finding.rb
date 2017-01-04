require 'sinatra'

#####
# Reporting Routes
#####

config_options = JSON.parse(File.read('./config.json'))

# Findings List Menu
get '/report/:id/findings' do
    @chart = config_options["chart"]

    @report = true
    id = params[:id]

    # Query for the first report matching the report_name
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    # Query for the findings that match the report_id
    if(config_options["dread"])
        @findings = Findings.all(:report_id => id, :order => [:dread_total.desc])
    elsif(config_options["cvss"])
        @findings = Findings.all(:report_id => id, :order => [:cvss_total.desc])
    else
        @findings = Findings.all(:report_id => id, :order => [:risk.desc])
    end

    @dread = config_options["dread"]
    @cvss = config_options["cvss"]

    haml :findings_list, :encode_html => true
end

# Generate a status report from the current findings
get '/report/:id/status' do
    id = params[:id]

    # Query for the report
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    # Query for the findings that match the report_id
    if(config_options["dread"])
        @findings = Findings.all(:report_id => id, :order => [:dread_total.desc])
    elsif(config_options["cvss"])
        @findings = Findings.all(:report_id => id, :order => [:cvss_total.desc])
    else
        @findings = Findings.all(:report_id => id, :order => [:risk.desc])
    end

    ## We have to do some hackery here for wordml
    findings_xml = ""
    findings_xml << "<findings_list>"
    @findings.each do |finding|
        ### Let's find the diff between the original and the new overview and remediation
        master_finding = CL_Library_finding.first(:pId => finding.master_id)

        findings_xml << finding.to_xml
    end
    findings_xml << "</findings_list>"

    findings_xml = meta_markup_unencode(findings_xml, @report.short_company_name)

    report_xml = "#{findings_xml}"

    xslt_elem = Xslt.first(:status_template => true)

    if xslt_elem

        # Push the finding from XML to XSLT
        xslt = Nokogiri::XSLT(File.read(xslt_elem.xslt_location))

        docx_xml = xslt.transform(Nokogiri::XML(report_xml))

        # We use a temporary file with a random name
        rand_file = "./tmp/#{rand(36**12).to_s(36)}.docx"

        # Create a temporary copy of the finding_template
        FileUtils::copy_file(xslt_elem.docx_location,rand_file)

        ### IMAGE INSERT CODE
        if docx_xml.to_s =~ /\[!!/
            # first we read in the current [Content_Types.xml]
            content_types = read_rels(rand_file,"[Content_Types].xml")

            # add the png and jpg handling to end of content types document
            if !(content_types =~ /image\/jpg/)
                content_types = content_types.sub("</Types>","<Default Extension=\"jpg\" ContentType=\"image/jpg\"/></Types>")
            end
            if !(content_types =~ /image\/png/)
                content_types = content_types.sub("</Types>","<Default Extension=\"png\" ContentType=\"image/png\"/></Types>")
            end
            if !(content_types =~ /image\/jpeg/)
                content_types = content_types.sub("</Types>","<Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/></Types>")
            end

            docx_modify(rand_file,content_types,"[Content_Types].xml")

            # replace all [!! image !!] in the document
            imgs = docx_xml.to_s.split("[!!")
            docx = imgs.first
            imgs.delete_at(0)

            imgs.each do |image_i|

                name = image_i.split("!!]").first.gsub(" ","")
                end_xml = image_i.split("!!]").last

                # search for the image in the attachments
                image = Attachments.first(:description => name, :report_id => id)

                # tries to prevent breakage in the case image dne
                if image
                    docx = image_insert(docx, rand_file, image, end_xml)
                else
                    docx << end_xml
                end

            end

        else
            # no images in finding
            docx = docx_xml.to_s
        end
        #### END IMAGE INSERT CODE

        docx_modify(rand_file,docx,'word/document.xml')

        send_file rand_file, :type => 'docx', :filename => "status.docx"

    else
        "You don't have a Finding Template (did you delete the temp?) -_- ... If you're an admin go to <a href='/admin/templates/add'>here</a> to add one."
    end


end

# Add a finding to the report
get '/report/:id/findings_add' do
    # Check for kosher name in report name
    id = params[:id]

    # Query for the first report matching the report_name
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    # Query for all Findings
    @findings = CL_Library_finding.all(:approved => true, :order => [:pTitle.asc])

    haml :findings_add, :encode_html => true
end

# Add a finding to the report
post '/report/:id/findings_add' do
    # Check for kosher name in report name
    id = params[:id]

    # Query for the first report matching the report_name
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    hosts = ""

    redirect to("/report/#{id}/findings") unless params[:finding]

	params[:finding].each do |finding|
		templated_finding = CL_Library_finding.first(:pId => finding.to_i)

		templated_finding.pId = nil
		attr = templated_finding.attributes
		attr.delete(:approved)
		attr["master_id"] = finding.to_i
		@newfinding = Findings.new(attr)
		@newfinding.report_id = id

        # because of multiple scores we need to make sure all are set
        # => leave it up to the user to make the calculation if they switch mid report
        @newfinding.dread_total = 0 if @newfinding.dread_total == nil
        @newfinding.cvss_total = 0  if @newfinding.cvss_total == nil
        @newfinding.risk = 0 if @newfinding.risk == nil

		@newfinding.save
	end

    # if we have hosts add them to the findings too
    params[:finding].each do |number|
        # if there are hosts to add with a finding they'll have a param syntax of "findingXXX=ip1,ip2,ip3"
        @findingnum = "finding#{number}"
        #TODO: merge with existing hosts (if any) probably should handle this host stuff in the db
        finding = Findings.first(:report_id => id, :master_id => number.to_i)

        if (params["#{@findingnum}"] != nil)
            params["#{@findingnum}"].split(",").each do |ip|
                #TODO: this is dirty. also should support different delimeters instead of just newline
                hosts << "<paragraph>" + ip.to_s + "</paragraph>"
            end

            finding.affected_hosts = hosts
            hosts = ""
        end
        finding.save
    end

    if(config_options["dread"])
        @findings = Findings.all(:report_id => id, :order => [:dread_total.desc])
    elsif(config_options["cvss"])
        @findings = Findings.all(:report_id => id, :order => [:cvss_total.desc])
    else
        @findings = Findings.all(:report_id => id, :order => [:risk.desc])
    end

    @dread = config_options["dread"]
    @cvss = config_options["cvss"]

    haml :findings_list, :encode_html => true
end

# Create a new finding in the report
get '/report/:id/findings/new' do
    # Query for the first report matching the report_name
    @report = get_report(params[:id])
    if @report == nil
        return "No Such Report"
    end

    # attachments autocomplete work
    temp_attaches = Attachments.all(:report_id => params[:id])
    @attaches = []
    temp_attaches.each do |ta|
        next unless ta.description =~ /png/ or ta.description =~ /jpg/
        @attaches.push(ta.description)
    end

    @dread = config_options["dread"]
    @cvss = config_options["cvss"]

    haml :create_finding, :encode_html => true
end

# Create the finding in the DB
post '/report/:id/findings/new' do
    error = mm_verify(request.POST)
    if error.size > 1
        return error
    end
    data = url_escape_hash(request.POST)

    if(config_options["dread"])
        data["dread_total"] = data["damage"].to_i + data["reproducability"].to_i + data["exploitability"].to_i + data["affected_users"].to_i + data["discoverability"].to_i
    elsif(config_options["cvss"])
        data = cvss(data)
    end

    id = params[:id]

    # Query for the first report matching the report_name
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    data["report_id"] = id

    @finding = Findings.new(data)
    @finding.save

    # because of multiple scores we need to make sure all are set
    # => leave it up to the user to make the calculation if they switch mid report
    @finding.dread_total = 0 if @finding.dread_total == nil
    @finding.cvss_total = 0 if @finding.cvss_total == nil
    @finding.risk = 0 if @finding.risk == nil
    @finding.save

    # for a parameter_pollution on report_id
    redirect to("/report/#{id}/findings")
end

# Edit the finding in a report
get '/report/:id/findings/:finding_id/edit' do
    id = params[:id]

    # Query for the first report matching the report_name
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    finding_id = params[:finding_id]

    # Query for all Findings
    @finding = Findings.first(:report_id => id, :id => finding_id)

    if @finding == nil
        return "No Such Finding"
    end

    # attachments autocomplete work
    temp_attaches = Attachments.all(:report_id => id)
    @attaches = []
    temp_attaches.each do |ta|
        next unless ta.description =~ /png/ or ta.description =~ /jpg/
        @attaches.push(ta.description)
    end

    @dread = config_options["dread"]
    @cvss = config_options["cvss"]

    haml :findings_edit, :encode_html => true
end

# Edit a finding in the report
post '/report/:id/findings/:finding_id/edit' do
    # Check for kosher name in report name
    id = params[:id]

    # Query for the report
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    finding_id = params[:finding_id]

    # Query for all Findings
    @finding = Findings.first(:report_id => id, :id => finding_id)

    if @finding == nil
        return "No Such Finding"
    end

    error = mm_verify(request.POST)
    if error.size > 1
        return error
    end
    data = url_escape_hash(request.POST)

    # to prevent title's from degenerating with &gt;, etc. [issue 237]
    data["title"] = data["title"].gsub('&amp;','&')

    if(config_options["dread"])
        data["dread_total"] = data["damage"].to_i + data["reproducability"].to_i + data["exploitability"].to_i + data["affected_users"].to_i + data["discoverability"].to_i
    elsif(config_options["cvss"])
        data = cvss(data)
    end
    # Update the finding with templated finding stuff
    @finding.update(data)

    # because of multiple scores we need to make sure all are set
    # => leave it up to the user to make the calculation if they switch mid report
    @finding.dread_total = 0 if @finding.dread_total == nil
    @finding.cvss_total = 0 if @finding.cvss_total == nil
    @finding.risk = 0 if @finding.risk == nil
    @finding.save

    redirect to("/report/#{id}/findings")
end

# Upload a finding from a report into the database
get '/report/:id/findings/:finding_id/upload' do
    # Check for kosher name in report name
    id = params[:id]

    # Query for the report
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    finding_id = params[:finding_id]

    # Query for the finding
    @finding = Findings.first(:report_id => id, :id => finding_id)

    if @finding == nil
        return "No Such Finding"
    end

    # We can't create a direct copy b/c CL_Library_finding doesn't have everything findings does
    # Check model/master.rb to compare
    attr = {
                    :title => @finding.title,
                    :damage => @finding.damage,
                    :reproducability => @finding.reproducability,
                    :exploitability => @finding.exploitability,
                    :affected_users => @finding.affected_users,
                    :discoverability => @finding.discoverability,
                    :dread_total => @finding.dread_total,
                    :cvss_base => @finding.cvss_base,
                    :cvss_impact => @finding.cvss_impact,
                    :cvss_exploitability => @finding.cvss_exploitability,
                    :cvss_temporal => @finding.cvss_temporal,
                    :cvss_environmental => @finding.cvss_environmental,
                    :cvss_modified_impact => @finding.cvss_modified_impact,
                    :cvss_total => @finding.cvss_total,
                    :effort => @finding.effort,
                    :type => @finding.type,
                    :overview => @finding.overview,
                    :poc => @finding.poc,
                    :remediation => @finding.remediation,
                    :approved => false,
                    :references => @finding.references,
                    :risk => @finding.risk
                    }

    @new_finding = CL_Library_finding.new(attr)
    @new_finding.save

    redirect to("/report/#{id}/findings")
end

# Remove a finding from the report
get '/report/:id/findings/:finding_id/remove' do
    # Check for kosher name in report name
    id = params[:id]

    # Query for the report
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    finding_id = params[:finding_id]

    # Query for all Findings
    @finding = Findings.first(:report_id => id, :id => finding_id)

    if @finding == nil
        return "No Such Finding"
    end

    # Update the finding with templated finding stuff
    @finding.destroy

    redirect to("/report/#{id}/findings")
end

# preview a finding
get '/report/:id/findings/:finding_id/preview' do
    id = params[:id]

    # Query for the report
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    # Query for the Finding
    @finding = Findings.first(:report_id => id, :id => params[:finding_id])

    if @finding == nil
        return "No Such Finding"
    end

    # this flags edited findings
    if @finding.master_id
        master = CL_Library_finding.first(:pId => @finding.master_id)
        @finding.overview = compare_text(@finding.overview, master.pOverview)
    end

    ## We have to do some hackery here for wordml
    findings_xml = ""
    findings_xml << "<findings_list>"
    findings_xml << @finding.to_xml
    findings_xml << "</findings_list>"

    findings_xml = meta_markup_unencode(findings_xml, @report.short_company_name)

    report_xml = "#{findings_xml}"

    xslt_elem = Xslt.first(:finding_template => true)

    if xslt_elem

        # Push the finding from XML to XSLT
        xslt = Nokogiri::XSLT(File.read(xslt_elem.xslt_location))

        docx_xml = xslt.transform(Nokogiri::XML(report_xml))

        # We use a temporary file with a random name
        rand_file = "./tmp/#{rand(36**12).to_s(36)}.docx"

        # Create a temporary copy of the finding_template
        FileUtils::copy_file(xslt_elem.docx_location,rand_file)

        ### IMAGE INSERT CODE
        if docx_xml.to_s =~ /\[!!/
            # first we read in the current [Content_Types.xml]
            content_types = read_rels(rand_file,"[Content_Types].xml")

            # add the png and jpg handling to end of content types document
            if !(content_types =~ /image\/jpg/)
                content_types = content_types.sub("</Types>","<Default Extension=\"jpg\" ContentType=\"image/jpg\"/></Types>")
            end
            if !(content_types =~ /image\/png/)
                content_types = content_types.sub("</Types>","<Default Extension=\"png\" ContentType=\"image/png\"/></Types>")
            end
            if !(content_types =~ /image\/jpeg/)
                content_types = content_types.sub("</Types>","<Default Extension=\"jpeg\" ContentType=\"image/jpeg\"/></Types>")
            end

            docx_modify(rand_file,content_types,"[Content_Types].xml")

            # replace all [!! image !!] in the document
            imgs = docx_xml.to_s.split("[!!")
            docx = imgs.first
            imgs.delete_at(0)

            imgs.each do |image_i|

                name = image_i.split("!!]").first.gsub(" ","")
                end_xml = image_i.split("!!]").last

                # search for the image in the attachments
                image = Attachments.first(:description => name, :report_id => id)

                # tries to prevent breakage in the case image dne
                if image
                    # inserts the image into the doc
                    docx = image_insert(docx, rand_file, image, end_xml)
                else
                    docx << end_xml
                end

            end

        else
            # no images in finding
            docx = docx_xml.to_s
        end
        #### END IMAGE INSERT CODE

        docx_modify(rand_file, docx,'word/document.xml')

        send_file rand_file, :type => 'docx', :filename => "#{@finding.title}.docx"
    else

        "You don't have a Finding Template (did you delete the default one?) -_- ... If you're an admin go to <a href='/admin/templates/add'>here</a> to add one."

    end
end