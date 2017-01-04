require 'sinatra'
require 'zip'

######
# Admin Interfaces
######

# get plugins available
get '/admin/plugins' do
    redirect to("/no_access") if not is_administrator?

    @plugins = []
    Dir[File.join(File.dirname(__FILE__), "../plugins/**/", "*.json")].each { |lib|
        @plugins.push(JSON.parse(File.open(lib).read))
    }

    @admin = true if is_administrator?
    @plugin = true if is_plugin?

    haml :plugins, :encode_html => true
end

# enable plugins
post '/admin/plugins' do
    redirect to("/no_access") if not is_administrator?

    @plugins = []
    Dir[File.join(File.dirname(__FILE__), "../plugins/**/", "*.json")].each { |lib|
        @plugins.push(JSON.parse(File.open(lib).read))
    }

    @plugins.each do |plug|
        p params
        if params[plug["name"]]
            plug["enabled"] = true
            File.open("./plugins/#{plug['name']}/plugin.json","w") do |f|
              f.write(JSON.pretty_generate(plug))
            end
        else
            plug["enabled"] = false
            File.open("./plugins/#{plug['name']}/plugin.json","w") do |f|
              f.write(JSON.pretty_generate(plug))
            end
        end
    end

    redirect to("/admin/plugins")
end

# upload plugin zip
post '/admin/plugin_upload' do
    redirect to("/no_access") if not is_administrator?
    redirect to("/no_access") if not is_plugin?

    # take each zip in turn
    params['files'].map{ |upf|
        # We use a random filename
        rand_file = "./tmp/#{rand(36**36).to_s(36)}"

        # reject if the file is above a certain limit
        if upf[:tempfile].size > 100000000
            return "File too large. 100MB limit"
        end

        # unzip the plugin and write it to the fs, writing the OS is possible but so is RCE
        File.open(rand_file, 'wb') {|f| f.write(upf[:tempfile].read) }

        # find the config.json file
        config = ""
        Zip::File.open(rand_file) do |zipfile|
            # read the config file
            zipfile.each do |entry|
                if entry.name == "plugin.json"
                    configj = entry.get_input_stream.read
                    config = JSON.parse(configj)
                end
            end
        end
        if config == ""
            return "plugin.json does not exist in zip."
        end

        Zip::File.open(rand_file) do |zipfile|
            # read the config file
            zipfile.each do |entry|
                # Extract to file/directory/symlink
                fn = "./plugins/#{config['name']}/"+entry.name

                # create the directory if dne
                dirj = fn.split("/")
                dirj.pop
                unless File.directory?(dirj.join("/"))
                    FileUtils.mkdir_p(dirj.join("/"))
                end

                next if fn[-1] == "/"
                # Read into memory
                content = entry.get_input_stream.read

                File.open(fn, 'a') {|f|
                    f.write(content)
                }

            end
        end
    }
    redirect to("/admin/plugins")
end

# get enabled plugins
get '/admin/admin_plugins' do
    @menu = []
    Dir[File.join(File.dirname(__FILE__), "../plugins/**/", "*.json")].each { |lib|
        pl = JSON.parse(File.open(lib).read)
        a = {}
        if pl["enabled"] and pl["admin_view"]
            # add the plugin to the menu
            a["name"] = pl["name"]
            a["description"] = pl["description"]
            a["link"] = pl["link"]
            @menu.push(a)
        end
    }
    haml :enabled_plugins, :encode_html => true
end

