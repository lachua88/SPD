require 'sinatra'
### Basic Routes

config_options = JSON.parse(File.read('./config.json'))

# Used for 404 responses
not_found do
    "Sorry, I don't know this page."
end

# Error catches
error do
    if settings.show_exceptions
        "Error!"+ env['sinatra.error'].name
    else
        "Error!! Check the process dump for the error or turn show_exceptions on to show in the web interface."
    end
end

# Run a session check on every route
["/info","/reports/*","/report/*","/","/logout","/admin/*","/master/*","/mapping/*"].each do |path|
    before path do
        next if request.path_info == "/reports/list"
        redirect '/reports/list' unless valid_session?
    end
end

before "/master/*" do
    redirect to("/no_access") if not is_administrator?
end

before "/mapping/*" do
    redirect to("/no_access") if not is_administrator?
end
#######

get '/' do
    redirect to("/reports/list")
end

get '/login' do
    redirect to("/reports/list")
end

# Handles the consultant information settings
get '/info' do
    @user = CL_User.first(:pUsername => get_username)

    if !@user
        @user = CL_User.new
        @user.pAuth_type = "AD"
        @user.pUsername = get_username
        @user.pType = "User"
        @user.save
    end

    haml :info, :encode_html => true
end

# Save the consultant information into the database
post '/info' do
    user = CL_User.first(:username => get_username)

    if !user
        user = CL_User.new
        user.pAuth_type = "AD"
        user.pUsername = get_username
        user.pType = "User"
    end

    user.pConsultant_email = params[:email]
    user.pConsultant_phone = params[:phone]
    user.pConsultant_title = params[:title]
    user.pConsultant_name = params[:name]
    user.pConsultant_company = params[:company]
    user.save

    redirect to("/info")
end

# Handles password reset
get '/reset' do
    redirect '/reports/list' unless valid_session?

    haml :reset, :encode_html => true
end

# Handles the password reset
post '/reset' do
    redirect '/reports/list' unless valid_session?

    # grab the user info
    user = CL_User.first(:username => get_username)

    # check if they are an LDAP user
    if user.pAuth_type != "Local"
        return "You are an LDAP user. You cannot change your password."
    end

    # check if the password is greater than 3 chars. legit complexity rules =/
    #   TODO add password complexity requirements
    if params[:new_pass].size < 4
        return "Srsly? Your password must be greater than 3 characters."
    end

    if params[:new_pass] != params[:new_pass_confirm]
        return "New password does not match."
    end

    if !(CL_User.authenticate(user.pUsername,params[:old_pass]))
        return "Old password is incorrect."
    end

    user.update(:password => params[:new_pass])
    @message = "success"
    haml :reset, :encode_html => true
end

post '/login' do
    user = CL_User.first(:pUsername => params[:username])

    if user and user.pAuth_type == "Local"

        usern = CL_User.authenticate(params["username"], params["password"])

        if usern and session[:session_id]
            # replace the session in the session table
            # TODO : This needs an expiration, session fixation
            @del_session = CL_Sessions.first(:pUsername => "#{usern}")
            @del_session.destroy if @del_session
            @curr_session = CL_Sessions.create(:pUsername => "#{usern}",:pSession_key => "#{session[:session_id]}")
            @curr_session.save

        end
    elsif user
		if options.ldap
			#try AD authentication
			usern = params[:username]
			data = url_escape_hash(request.POST)
            if usern == "" or params[:password] == ""
                redirect to("/")
            end

			user = "#{options.domain}\\#{data["username"]}"
			ldap = Net::LDAP.new :host => "#{options.dc}", :port => 636, :encryption => :simple_tls, :auth => {:method => :simple, :username => user, :password => params[:password]}

			if ldap.bind
			   # replace the session in the session table
			   @del_session = CL_Sessions.first(:username => "#{usern}")
			   @del_session.destroy if @del_session
			   @curr_session = CL_Sessions.create(:username => "#{usern}",:pSession_key => "#{session[:session_id]}")
			   @curr_session.save
			end
		end
    end

    redirect to("/")
end

## We use a persistent session table, one session per user; no end date
get '/logout' do
    if session[:session_id]
        sess = CL_Sessions.first(:pSession_key => session[:session_id])
        if sess
            sess.destroy
        end
    end

    redirect to("/")
end

# rejected access (admin functionality)
get "/no_access" do
    return "Sorry. You Do Not have access to this resource."
end
