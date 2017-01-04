require 'sinatra'
### Basic Routes

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
    user = CL_User.first(:pUsername => get_username)

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

# rejected access (admin functionality)
get "/no_access" do
    return "Sorry. You Do Not have access to this resource."
end
