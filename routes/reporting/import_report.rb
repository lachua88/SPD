require 'sinatra'

#####
# Reporting Routes
#####

config_options = JSON.parse(File.read('./config.json'))

# Import a report
get '/report/import' do
    haml :import_report
end

# Import a report
post '/report/import' do
    redirect to("/report/import") unless params[:file]

    # reject if the file is above a certain limit
    if params[:file][:tempfile].size > 1000000
        return "File too large. 1MB limit"
    end

    json_file = params[:file][:tempfile].read
    line = JSON.parse(json_file)

    line["report"]["id"] = nil

    f = Reports.create(line["report"])
    f.save

    # now add the findings
    line["findings"].each do |finding|
        finding["id"] = nil
        finding["master_id"] = nil
        finding["report_id"] = f.id
        finding["finding_modified"] = nil

        finding["dread_total"] = 0 if finding["dread_total"] == nil
        finding["cvss_total"] = 0 if finding["cvss_total"] == nil
        finding["risk"] = 1 if finding["risk"] == nil

        g = Findings.create(finding)
        g.save
    end

    if line["Attachments"]
        # now add the attachments
        line["Attachments"].each do |attach|
            puts "importing attachments"
            attach["id"] = nil

            attach["filename"] = "Unknown" if attach["filename"] == nil
            if attach["filename_location"] =~ /./
                a = attach["filename_location"].split(".").last
                loc = "./attachments/" + a.gsub("/attachments/","")
                attach["filename_location"] = loc
            else
                loc = "./attachments/" + attach["filename_location"]
            end
            attach["filename_location"] = loc

            attach["report_id"] = f.id
            attach["description"] = "No description" if attach["description"] == nil
            g = Attachments.create(attach)
            g.save
        end
    end

    # we should redirect to the newly imported report
    redirect to("/report/#{f.id}/edit")
end
