require 'zip'
require 'sinatra'

######
# Template Document Routes
######

# Export a findings database
get '/master/export' do
    json = ""

    findings = CL_Library_finding.all

    local_filename = "./tmp/#{rand(36**12).to_s(36)}.json"
    File.open(local_filename, 'w') {|f| f.write(JSON.pretty_generate(findings)) }

    send_file local_filename, :type => 'json', :filename => "Library_finding.json"
end