require 'sinatra'

#####
# Reporting Routes
#####

config_options = JSON.parse(File.read('./config.json'))

# upload nessus xml files to be processed
get '/report/:id/import_nessus' do
    id = params[:id]

    @nessusmap = config_options["nessusmap"]

    # Query for the first report matching the id
    @report = get_report(id)

    haml :import_nessus, :encode_html => true
end

# upload burp xml files to be processed
get '/report/:id/import_burp' do
    id = params[:id]

    @burpmap = config_options["burpmap"]

    # Query for the first report matching the id
    @report = get_report(id)

    haml :import_burp, :encode_html => true
end

# auto add serpico findings if mapped to nessus ids
post '/report/:id/import_autoadd' do
    type = params[:type]

    xml = params[:file][:tempfile].read
    if (xml =~ /^<NessusClientData_v2>/ && type == "nessus")
        import_nessus = true
        vulns = parse_nessus_xml(xml, config_options["threshold"])
    elsif (xml =~ /^<issues burpVersion/ && type == "burp")
        import_burp = true
        vulns = parse_burp_xml(xml)
    else
        return "File does not contain valid XML import data"
    end

    # reject if the file is above a certain limit
    #if params[:file][:tempfile].size > 1000000
    #        return "File too large. 1MB limit"
    #end
    # Check for kosher name in report name
    id = params[:id]

    add_findings = Array.new
    dup_findings = Array.new
    autoadd_hosts = Hash.new

    # Query for the first report matching the report_name
    @report = get_report(id)

    if @report == nil
        return "No Such Report"
    end

    # load all findings
    @findings = CL_Library_finding.all(:order => [:pTitle.asc])

    # parse nessus xml into hash
    #nessus_vulns = parse_nessus_xml(nessus_xml)

    # determine findings to add from vuln data
    # host/ip is key, value is array of vuln ids
    vulns.keys.each do |i|
        vulns[i].each do |v|

			# if serpico finding id maps to nessus/burp plugin id, add to report
            if import_nessus
                @mappings = NessusMapping.all(:pluginid => v)
            elsif import_burp
                @mappings = BurpMapping.all(:pluginid => v)
            end
            # add affected hosts for each finding
            if (@mappings)
                @mappings.each do |m|
                    if autoadd_hosts[m.templatefindings_id]
                        # only one host/url per finding (regardless of ports and urls). this should change in the future
                        if not autoadd_hosts[m.templatefindings_id].include?(i)
                            autoadd_hosts[m.templatefindings_id] << i
                        end
                    else
                        autoadd_hosts[m.templatefindings_id] = []
                        autoadd_hosts[m.templatefindings_id] << i
                    end
                    add_findings << m.templatefindings_id
                end
            end
        end
    end

    add_findings = add_findings.uniq

    # create new findings from an import
    # TODO: This will duplicate if the user already has a nessus id mapped
    if config_options["auto_import"]
        vulns["findings"].each do |vuln|
            vuln.report_id = id
            vuln.save
        end
    end

    if add_findings.size == 0
        redirect to("/report/#{id}/findings")
    else
        @autoadd = true

        add_findings.each do |finding|
            # if the finding already exists in the report dont add
            currentfindings = Findings.all(:report_id => id)
            currentfindings.each do |cf|
                if cf.master_id == finding.to_i
                    if not dup_findings.include?(finding.to_i)
                        dup_findings << finding.to_i
                    end
                    add_findings.delete(finding.to_i)
                end
            end
        end
        @autoadd_hosts = autoadd_hosts
        @dup_findings = dup_findings.uniq
        @autoadd_findings = add_findings
    end
    haml :findings_add, :encode_html => true
end
