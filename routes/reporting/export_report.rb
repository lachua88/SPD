require 'sinatra'

#####
# Reporting Routes
#####

config_options = JSON.parse(File.read('./config.json'))

# Export a report
get '/report/:id/export' do
    json = {}

    id = params[:id]
    report = get_report(id)

    # bail without a report
    redirect to("/") unless report

    # add the report
    json["report"] = report

    # add the findings
    findings = CL_Default_finding.all(:pReport_id => id)
    json["findings"] = findings

    # add the exports
    attachments = Attachments.all(:report_id => id)
    json["Attachments"] = attachments

    local_filename = "./tmp/#{rand(36**12).to_s(36)}.json"
    File.open(local_filename, 'w') {|f| f.write(JSON.pretty_generate(json)) }

    send_file local_filename, :type => 'json', :filename => "exported_report.json"
end