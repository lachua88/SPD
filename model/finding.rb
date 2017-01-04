require 'rubygems'
require 'data_mapper'
require 'digest/sha1'
require 'dm-migrations'

# Initialize the Master DB
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/master.db")

class CL_Attachments
    include DataMapper::Resource

    property :pId, Serial
    property :pFilename, String, :length => 50
    property :pFilename_location, String, :length => 400
    property :pReport_id, String, :length => 30
    property :pDescription, String, :length => 500

end

class CL_Shared_finding
    include DataMapper::Resource

    property :pId, Serial
    property :pApproved, Boolean, :required => false, :default => true
    
    property :pAttachment_id, Integer
    property :pAffected_module, Integer, :required => false

    property :pCVSS, Float
    
    property :pRisk_rating, String
    property :pOWASP, String, :required => true, :length => 3
    property :pCWE, String, :required => true, :length => 200
    property :pTitle, String, :required => true, :length => 200
    property :pObservation, String, :length => 20000, :required => false
    property :pLikelihood, String, :length => 20000, :required => false
    property :pRecommendation, String, :length => 20000, :required => false

end

class CL_Report_finding < CL_Shared_finding

    property :pReport_id, Integer, :required => true
    property :pMaster_id, Integer, :required => false

end

class CL_Report_misc
    include DataMapper::Resource

    property :pId, Serial
    property :pStatus, Boolean, :required => false, :default => true
    property :pFAttachment_id, Integer
    property :pMComment, String, :length => 20000, :required => false
    property :pDComment, String, :length => 20000, :required => false
end

class CL_Library_finding < CL_Shared_finding

    property :pOverview, String, :length => 20000, :required => false 
    property :pReferences, String, :length => 20000, :required => false

    # CVSS
   
end

DataMapper.finalize

# any differences between the data store and the data model should be fixed by this
#   As discussed in http://datamapper.org/why.html it is limited. Hopefully we never create conflicts.
DataMapper.auto_upgrade!
