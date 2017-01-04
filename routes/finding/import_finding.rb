require 'zip'
require 'sinatra'

######
# Template Document Routes
######

# Import a findings database
get '/master/import' do
    haml :import_templates
end

# Import a findings database
post '/master/import' do
    redirect to("/master/import") unless params[:file]

    # reject if the file is above a certain limit
    if params[:file][:tempfile].size > 1000000
        return "File too large. 1MB limit"
    end

    json_file = params[:file][:tempfile].read
    line = JSON.parse(json_file)

    line.each do |j|
        j["id"] = nil

        finding = CL_Library_finding.first(pTitle => j["title"])

        if finding
            #the finding title already exists in the database
            if finding["overview"] == j["overview"] and finding["remediation"] == j["remediation"]
                # the finding already exists, ignore it
            else
                # it's a modified finding
                j["title"] = "#{j['title']} - [Uploaded Modified Templated Finding]"
                params[:approved] !=nil ? j["approved"] = true : j["approved"] = false
                f = CL_Library_finding.create(j)
                f.save
            end
        else
            params[:approved] != nil ? j["approved"] = true : j["approved"] = false
            f = CL_Library_finding.first_or_create(j)
            f.save
        end
    end
    redirect to("/master/findings")
end

