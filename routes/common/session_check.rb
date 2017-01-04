require 'sinatra'
### Basic Routes

# Run a session check on every route
["/info","/reports/*","/report/*","/","/logout","/admin/*","/master/*","/mapping/*"].each do |path|
    before path do
        next if request.path_info == "/reports/list"
        redirect '/reports/list' unless valid_session?
    end
end