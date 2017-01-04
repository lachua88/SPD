require 'sinatra'

#####
# Reporting Routes
#####

config_options = JSON.parse(File.read('./config.json'))

# Generate the report
get '/report/:id/generate' do
    id = params[:id]

    # Query for the report
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    user = CL_User.first(:pUsername => get_username)

    if user
        @report.consultant_name = user.pConsultant_name
        @report.consultant_phone = user.pConsultant_phone
        @report.consultant_email = user.pConsultant_email
        @report.consultant_title = user.pConsultant_title
        @report.consultant_company = user.pConsultant_company

    else
        @report.consultant_name = ""
        @report.consultant_phone = ""
        @report.consultant_email = ""
        @report.consultant_title = ""
        @report.consultant_company = ""

    end
    @report.save

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

        # This flags new or edited findings
        if finding.master_id
            master = CL_Library_finding.first(:pId => finding.master_id)
            if master
                finding.overview = compare_text(finding.overview, master.pOverview)
                finding.remediation = compare_text(finding.remediation, master.pRemediation)
            else
                finding.overview = compare_text(finding.overview, nil)
                finding.remediation = compare_text(finding.remediation, nil)
            end
        else
            finding.overview = compare_text(finding.overview, nil)
            finding.remediation = compare_text(finding.remediation, nil)
        end
        findings_xml << finding.to_xml
    end

    findings_xml << "</findings_list>"

    # Replace the stub elements with real XML elements
    findings_xml = meta_markup_unencode(findings_xml, @report.short_company_name)

    # check if the report has user_defined variables
    if @report.user_defined_variables

        # we need the user defined variables in xml
        udv_hash = JSON.parse(@report.user_defined_variables)
        udv = "<udv>"
        udv_hash.each do |key,value|
            udv << "<#{key}>"
            udv << "#{value}"
            udv << "</#{key}>\n"
        end
        udv << "</udv>"
    else
        udv = ""
    end

    report_xml = "<report>#{@report.to_xml}#{udv}#{findings_xml}</report>"

    xslt_elem = Xslt.first(:report_type => @report.report_type)

    # Push the finding from XML to XSLT
    xslt = Nokogiri::XSLT(File.read(xslt_elem.xslt_location))

    docx_xml = xslt.transform(Nokogiri::XML(report_xml))

    # We use a temporary file with a random name
    rand_file = "./tmp/#{rand(36**12).to_s(36)}.docx"

    # Create a temporary copy of the word doc
    FileUtils::copy_file(xslt_elem.docx_location,rand_file)

    ### IMAGE INSERT CODE
    if docx_xml.to_s =~ /\[!!/
        puts "|+| Trying to insert image --- "

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
                    # inserts the image
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

    send_file rand_file, :type => 'docx', :filename => "#{@report.report_name}.docx"
end

# generate an asciidoc version of current findings
get '/report/:id/asciidoc_status' do
    id = params[:id]
    report = get_report(id)

    # bail without a report
    redirect to("/") unless report

    # add the findings
    findings = Findings.all(:report_id => id)

    ascii_doc_ = ""
    findings.each do |finding|
        ascii_doc_ << gen_asciidoc(finding,config_options["dread"])
    end

    local_filename = "./tmp/#{rand(36**12).to_s(36)}.asd"
      File.open(local_filename, 'w') {|f| f.write(ascii_doc_) }

    send_file local_filename, :type => 'txt', :filename => "report_#{id}_findings.asd"
end

# generate a presentation of current report
get '/report/:id/presentation' do
    # check the user has installed reveal
    if !(File.directory?(Dir.pwd+"/public/reveal.js"))
        return "reveal.js not found in /public/ directory. To install:<br><br> 1. Goto [INSTALL_DIR]/public/ <br>2.run 'git clone https://github.com/hakimel/reveal.js.git'<br>3. Restart Serpico"
    end

    id = params[:id]

    @report = get_report(id)

    # bail without a report
    redirect to("/") unless @report

    # add the findings
    @findings = Findings.all(:report_id => id)

    # add images into presentations
    @images = []
    @findings.each do |find|
        a = {}
        if find.presentation_points
            find.presentation_points.to_s.split("<paragraph>").each do |pp|
                next unless pp =~ /\[\!\!/
                img = pp.split("[!!")[1].split("!!]").first
                a["name"] = img
                img_p = Attachments.first( :description => img)
                a["link"] = "/report/#{id}/attachments/#{img_p.id}"
                @images.push(a)
            end
        end
    end
    @dread = config_options["dread"]
    @cvss = config_options["cvss"]

    haml :presentation, :encode_html => true, :layout => false
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