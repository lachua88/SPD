require 'sinatra'
### Basic Routes

get '/login' do
    redirect to("/reports/list")
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
