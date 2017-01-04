require 'sinatra'

######
# Admin Interfaces
######

get '/admin/' do
    redirect to("/no_access") if not is_administrator?
    @admin = true

    haml :admin, :encode_html => true
end
