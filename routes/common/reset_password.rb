require 'sinatra'
### Basic Routes

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