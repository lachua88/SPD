require 'rubygems'
require 'data_mapper'
require 'digest/sha1'
require 'dm-migrations'

# Initialize the Master DB
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/master.db")



class VulnMappings
  include DataMapper::Resource

  property :id, Serial
  property :templatefindings_id, String, :required => true
  property :msf_ref, String, :required => true
  #property :type, String, :required => true

end

class NessusMapping
    include DataMapper::Resource

    property :id, Serial
    property :templatefindings_id, String, :required => true
    property :pluginid, String, :required => true
end

class BurpMapping
    include DataMapper::Resource

    property :id, Serial
    property :templatefindings_id, String, :required => true
    property :pluginid, String, :required => true
end

DataMapper.finalize

# any differences between the data store and the data model should be fixed by this
#   As discussed in http://datamapper.org/why.html it is limited. Hopefully we never create conflicts.
DataMapper.auto_upgrade!
