require 'sinatra'
require 'zip'

config_options = JSON.parse(File.read('./config.json'))

######
# Admin Interfaces
######

get '/admin/config' do
    redirect to("/no_access") if not is_administrator?

    @config = config_options
    if config_options["cvss"]
        @scoring = "cvss"
    elsif config_options["dread"]
        @scoring = "dread"
    else
        @scoring = "default"
    end

    haml :config, :encode_html => true
end

post '/admin/config' do
    redirect to("/no_access") if not is_administrator?

    ft = params["finding_types"].split(",")
    udv = params["user_defined_variables"].split(",")

    config_options["finding_types"] = ft
    config_options["user_defined_variables"] = udv
    config_options["port"] = params["port"]
    config_options["use_ssl"] = params["use_ssl"] ? true : false
    config_options["bind_address"] = params["bind_address"]
    config_options["ldap"] = params["ldap"] ? true : false
    config_options["ldap_domain"] = params["ldap_domain"]
    config_options["ldap_dc"] = params["ldap_dc"]
    config_options["burpmap"] = params["burpmap"] ? true : false
    config_options["nessusmap"] = params["nessusmap"] ? true : false
    config_options["vulnmap"] = params["vulnmap"] ? true : false
    config_options["logo"] = params["logo"]
    config_options["auto_import"] = params["auto_import"] ? true : false
    config_options["chart"] = params["chart"] ? true : false
    config_options["threshold"] = params["threshold"]
    config_options["show_exceptions"] = params["show_exceptions"] ? true : false

    if params["risk_scoring"] == "CVSS"
        config_options["dread"] = false
        config_options["cvss"] = true
    elsif params["risk_scoring"] == "DREAD"
        config_options["dread"] = true
        config_options["cvss"] = false
    else
        config_options["dread"] = false
        config_options["cvss"] = false
    end

    File.open("./config.json","w") do |f|
      f.write(JSON.pretty_generate(config_options))
    end
    redirect to("/admin/config")
end