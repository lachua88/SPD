require 'rubygems'
require './model/user'

if ARGV.size < 3
	# With no arguments a list of users is dumped
	puts "\n ****Usage: create_user.rb username password level \n"
	
	users = CL_User.all

	puts "\n Current Users asd"
	puts "Username \t Type \t Created At \n "
	
	users.each do |u|
		puts "#{u.pUsername} \t #{u.pType} \t #{u.pCreated_at}"
	end
	puts "\n"
	exit
end

user = CL_User.new
user.pUsername = ARGV[0]
user.password = ARGV[1]
user.pType = ARGV[2]
user.pAuth_type = "Local"
user.save
