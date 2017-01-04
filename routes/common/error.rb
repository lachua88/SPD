require 'sinatra'
### Basic Routes

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