require 'sinatra'

######
# Admin Interfaces
######

get '/admin/add_user' do
    redirect to("/no_access") if not is_administrator?

    @admin = true

    haml :add_user, :encode_html => true
end

get '/admin/list_user' do
    redirect to("/no_access") if not is_administrator?
    @admin = true
    @users =  CL_User.all
    @plugin = is_plugin?

    haml :list_user, :encode_html => true
end

get '/admin/edit_user/:id' do
    redirect to("/no_access") if not is_administrator?

    @user = CL_User.first(:pId => params[:id])

    haml :add_user, :encode_html => true
end

get '/admin/delete/:id' do
    redirect to("/no_access") if not is_administrator?

    @user = CL_User.first(:pId => params[:id])
    @user.destroy if @user

    redirect to('/admin/list_user')
end

get '/admin/add_user/:id' do
    if not is_administrator?
        id = params[:id]
        unless get_report(id)
            redirect to("/no_access")
        end
    end

    @users = CL_User.all(:order => [:pUsername.asc])
    @report = Reports.first(:id => params[:id])

    if is_administrator?
      @admin = true
    end

    haml :add_user_report, :encode_html => true
end


get '/admin/del_user_report/:id/:author' do
    if not is_administrator?
        id = params[:id]
        unless get_report(id)
            redirect to("/no_access")
        end
    end

    report = Reports.first(:id => params[:id])

    if report == nil
        return "No Such Report"
    end

    authors = report.authors

    if authors
        authors = authors - ["#{params[:author]}"]
    end

    report.authors = authors
    report.save

    redirect to("/reports/list")
end

# Create a new user
post '/admin/add_user' do
    redirect to("/no_access") if not is_administrator?

    user = CL_User.first(:pUsername => params[:username])

    if user
        if params[:password] and params[:password].size > 1
            # we have to hardcode the input params to prevent param pollution
            user.update(:pType => params[:type], :pAuth_type => params[:auth_type], :password => params[:password])
        else
            # we have to hardcode the params to prevent param pollution
            user.update(:pType => params[:type], :pAuth_type => params[:auth_type])
        end
    else
        user = CL_User.new
        user.pUsername = params[:username]
        user.password = params[:password]
        user.pType = params[:type]
        user.pAuth_type = params[:auth_type]
        user.save
    end

    redirect to('/admin/list_user')
end

post '/admin/add_user/:id' do
    if not is_administrator?
        id = params[:id]
        unless get_report(id)
            redirect to("/no_access")
        end
    end

    report = Reports.first(:id => params[:id])

    if report == nil
        return "No Such Report"
    end

    authors = report.authors

    if authors
        authors = authors.push(params[:author])
    else
        authors = ["#{params[:author]}"]
    end

    report.authors = authors
    report.save

    redirect to("/reports/list")
end