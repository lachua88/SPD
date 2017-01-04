require 'sinatra'

#####
# Reporting Routes
#####

config_options = JSON.parse(File.read('./config.json'))

# set msf rpc settings for report
get '/report/:id/msfsettings' do
    id = params[:id]
    @report = get_report(id)

    # bail without a report
    redirect to("/") unless @report

    @vulnmap = config_options["vulnmap"]
    @msfsettings = RemoteEndpoints.first(:report_id => id)

    haml :msfsettings, :encode_html => true
end

# set msf rpc settings for report
post '/report/:id/msfsettings' do
    id = params[:id]
    @report = get_report(id)

    # bail without a report
    redirect to("/") unless @report

    if !config_options["vulnmap"]
        return "Metasploit integration not enabled"
    end

    msfsettings = RemoteEndpoints.first(:report_id => id)

    if msfsettings
        msfsettings.update(:ip => params[:ip], :port => params[:port], :workspace => params[:workspace], :user => params[:user], :pass => params[:pass])
    else
        msfsettings = RemoteEndpoints.new
        msfsettings["report_id"] = @report.id
        msfsettings["ip"] = params[:ip]
        msfsettings["port"] = params[:port]
        msfsettings["type"] = "msfrpc"
        msfsettings["workspace"] = params[:workspace]
        msfsettings["user"] = params[:user]
        msfsettings["pass"] = params[:pass]
        msfsettings.save
    end

    redirect to("/report/#{@report.id}/findings")
end

# display hosts from msf db
get '/report/:id/hosts' do
    id = params[:id]
    @report = get_report(id)
    @vulnmap = config_options["vulnmap"]

    # bail without a report
    redirect to("/") unless @report

    msfsettings = RemoteEndpoints.first(:report_id => id)
    if !msfsettings
        return "You need to setup a metasploit RPC connection to use this feature. Do so <a href='/report/#{id}/msfsettings'>here</a>"
    end

    #setup msfrpc handler
    rpc = msfrpc(@report.id)
    if rpc == false
        return "ERROR: Connection to metasploit failed. Make sure you have msfprcd running and the settings in Serpico are correct."
    end

    # get hosts from msf db
    res = rpc.call('console.create')
    rpc.call('db.set_workspace', msfsettings.workspace)
    res = rpc.call('db.hosts', {:limit => 10000})
    @hosts = res["hosts"]

    haml :dbhosts, :encode_html => true
end

# display vulns from msf db
get '/report/:id/vulns' do
    id = params[:id]
    @report = get_report(id)
    @vulnmap = config_options["vulnmap"]

    # bail without a report
    redirect to("/") unless @report

    msfsettings = RemoteEndpoints.first(:report_id => id)
    if !msfsettings
        return "You need to setup a metasploit RPC connection to use this feature. Do so <a href='/report/#{id}/msfsettings'>here</a>"
    end

    # setup msfrpc handler
    rpc = msfrpc(@report.id)
    if rpc == false
        return "connection to MSF RPC deamon failed. Make sure you have msfprcd running and the settings in Serpico are correct."
    end

    # get vulns from msf db
    res = rpc.call('console.create')
    rpc.call('db.set_workspace', msfsettings.workspace)
    res = rpc.call('db.vulns', {:limit => 10000})
    @vulns = res["vulns"]

    haml :dbvulns, :encode_html => true
end

# autoadd vulns from msf db
get '/report/:id/import/vulns' do
    id = params[:id]
    @report = get_report(id)

    # bail without a report
    redirect to("/") unless @report

    if @report == nil
        return "No Such Report"
    end

    if not config_options["vulnmap"]
        return "Metasploit integration not enabled."
    end

    add_findings = Array.new
    dup_findings = Array.new
    autoadd_hosts = Hash.new

    # load msf settings
    msfsettings = RemoteEndpoints.first(:report_id => id)
    if !msfsettings
      return "You need to setup a metasploit RPC connection to use this feature. Do so <a href='/report/#{id}/msfsettings'>here</a>"
    end

    # setup msfrpc handler
    rpc = msfrpc(@report.id)
    if rpc == false
        return "connection to MSF RPC deamon failed. Make sure you have msfprcd running and the settings in Serpico are correct."
    end

    # determine findings to add from vuln data
    vulns = get_vulns_from_msf(rpc, msfsettings.workspace)

    # load all findings
    @findings = CL_Library_finding.all(:order => [:pTitle.asc])

    # determine findings to add from vuln data
    # host/ip is key, value is array of vuln ids
    vulns.keys.each do |i|
        vulns[i].each do |v|

            # if serpico finding id maps to a ref from MSF vuln db, add to report
            @mappings = VulnMappings.all(:msf_ref => v)
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
        p "auto_import function not supported with MSF intergration"
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