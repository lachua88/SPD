require 'sinatra'

#####
# Reporting Routes
#####

# get enabled plugins
get '/report/:id/report_plugins' do
    id = params[:id]
    @report = get_report(id)

    # bail without a report
    redirect to("/") unless @report

    @menu = []
    Dir[File.join(File.dirname(__FILE__), "../plugins/**/", "*.json")].each { |lib|
        pl = JSON.parse(File.open(lib).read)
        a = {}
        if pl["enabled"] and pl["report_view"]
            # add the plugin to the menu
            a["name"] = pl["name"]
            a["description"] = pl["description"]
            a["link"] = pl["link"]
            @menu.push(a)
        end
    }
    haml :enabled_plugins, :encode_html => true
end

