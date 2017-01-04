require 'rubygems'
require './model/user.rb'

user = cl_User.first

print "Would you like to change the password for #{user.pUsername} (Y/n)  "

change = gets.chomp.downcase

if change == "y" or change == ""

	password = rand(36**10).to_s(36)

    user.update(:pType => "Administrator", :pAuth_type => "Local", :aPassword => password)

	puts "User successfully updated."
	
	puts "\t\t New password is : #{password} \n\n"
else
	puts "Exiting..."
end
