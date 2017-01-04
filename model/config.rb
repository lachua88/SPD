require 'rubygems'
require 'data_mapper'
require 'digest/sha1'
require 'dm-migrations'

# Initialize the Master DB
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/master.db")

# For a metasploit connector eventually
class RemoteEndpoints
    include DataMapper::Resource

    property :id, Serial
    property :ip, String
    property :port, String
    property :type, String
    property :report_id, Integer
    property :workspace, String
    property :user, String
    property :pass, String

end

class Hosts
    include DataMapper::Resource

    property :id, Serial
    property :ip, String
    property :port, String

end

DataMapper.finalize

# any differences between the data store and the data model should be fixed by this
#   As discussed in http://datamapper.org/why.html it is limited. Hopefully we never create conflicts.
DataMapper.auto_upgrade!
