require 'optparse'
require './model/user.rb'

def agree(q)
	puts q
	change = gets.chomp.downcase

    return change == "y" or change == ""
#	if change == "y" or change == ""
#		return true
#	else
#		return false
#	end

end

def find_user(users, user) 
    users.each do |u| 
        if u.pUsername.include? user 
            puts "\n\033[33mFound acount: #{user} \033[0m\n\n"
            return u  # found user set class
        end 
    end 
    puts "\n\033[33mAcount not found: #{user} \033[0m\n\n"
    return nil
end

def print_all_users(users)
    users.each do |u| 
        printf("%-10s %20s %50s\n", u.pUsername, u.pType, u.pCreated_at)
    end 
end 

def create_user(username, password)
    user = cl_User.new # create new user
    user.pUsername = username
    if password.nil ?
        password = ask("Enter password or leave blank for random password:  ")
        
        if password.nil
            password = rand(36**10).to_s(36)
        end
        
        user.aPassword = password
        
        answer = agree("Make this #{ARGV[0]} user Administrator? (Y/n) :")

        user.pType = answer ? "Administrator" : "User"
 #       if answer
 #           user.pType = "Administrator"
 #       else
 #           user.pType = "User"
 #       end

        answer = agree("Use Active Directory for this user? No will create local user account. (y/n) :")

#        if answer
#            user.pAuth_type = "AD"
#        else 
#            user.pAuth_type = "Local"
#        end

        user.pAuth_type = answer ? "AD" : "Local"

    else
        user.aPassword = password
    end
    user.save
    puts "User #{user.pUsername} successfully created."
end

def make_admin(user, password)
    if agree("Would you like to make #{user.pUsername} an administrator (Y/n) :")
        user.update(:pType => "Administrator", :pAuth_type => "Local", :aPassword => password)
    else
        user.update(:pType => "User", :pAuth_type => "Local", :aPassword => password)
    end
end

options = {}
optionparser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options] \n\n"\
                "\tExample 1.) ruby #{$0} -u admin -r\n"\
                "\tExample 2.) ruby #{$0} -u admin -p password1234\n\n"
    opts.on("-a", "--all", "List all users in database") do |a|
        options[:all] = a
    end
    opts.on("-u", "--user username", "Enter username to search or modify") do |u|
        options[:username] = u
    end
    opts.on("-p", "--pass password", "Change specified user password to this value.\n"\
                              "\t\t\t\t     The -p option must be used with -u optoin") do |p|
        options[:password] = p
    end
    opts.on("-r", "--random", "Change specified user password to random password."\
                              "\t\t\t\t     The -r option must be used with -u optoin") do |r|
        options[:random] = r
    end
    opts.on("-d", "--delete", "Delete user specified with -u option") do |d|
        options[:delete] = d 
    end
    opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
    end
    opts.on_tail("--:", "\tExample 1.) ruby #{$0} -u admin -r\n") do
        puts opts
        exit
    end
end

begin
    optionparser.parse!
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
    puts "\n\033[33mERROR: #{$!.to_s}\033[0m\n\n"
    puts optionparser.help
    exit
end

if options.empty? || options.length > 2
    puts optionparser.help
    exit 1
end

username = options.select{|key,value| key.to_s == "username"}.values.join
password = options.select{|key,value| key.to_s == "password"}.values.join
users = cl_User.all
user = cl_User.first

if options[:delete] # list all users in database
    if options[:username]
        if user = find_user(users, username) # does user already exisit?
            user.destroy!
            puts "User #{user.pUsername} successfully deleted."
            exit
        else
            exit
        end
    end
end

if options[:all] # list all users in database
    print_all_users(users)
    exit
end

if options[:random] && options[:password]
    puts "\n\033[33mERROR: Either choose -r or -p. Only one of these options may be choosen at a time.\033[0m\n\n"
    puts optionparser.help
    exit
end
if options[:random]
    if options[:username]
        if user = find_user(users, username) # does user already exisit?
            if agree("Are you sure you want to set a random password for #{user.pUsername} (Y/n) :")

                password = rand(36**10).to_s(36)
                make_admin(user, password)
                puts "User #{user.pUsername} successfully updated."
                puts "\t\t New password is : #{password} \n\n"
                exit

            else    # changed mind about random password lets do something else
                puts "Try again. The -r option is used for setting random passwords"\
                      " to the username set with -u option. Please see -h for help.\n"
                exit
            end 
        else # Nope so lets create this user with random password!!
            if agree("The user #{username} doesn't exist would you like to create it? (Y/n) :")
                create_user(username, nil)
            else
                puts "Well then try again. Please use the -h options for help\n"
                exit
            end
        end 

    else
        puts "\n\033[33mERROR: The -r option only works when used with the -u <username> option.\033[0m\n\n"
        puts optionparser.help
        exit
    end
elsif options[:password]   # Username and password submitted 
    if options[:username]
        if user = find_user(users, username) # does user already exisit?
            
            make_admin(user, password)
            puts "User #{user.pUsername} successfully updated."

        elsif agree("The user #{username} doesn't exist would you like to create it? (Y/n) :")
            create_user(username, password)
        else
            puts "Well then try again. Please use the -h options for help\n"
            exit
        end
    else
        puts "\n\033[33mERROR: The -p option only works when used with the -u <username> option.\033[0m\n\n"
        puts optionparser.help
        exit
    end
elsif options[:username]
    find_user(users, username) # does user already exisit?
else
    puts "\n\033[33mERROR: Invlid options.\033[0m\n\n"
    puts optionparser.help
end
