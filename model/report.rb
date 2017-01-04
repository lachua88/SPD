require 'rubygems'
require 'data_mapper'
require 'digest/sha1'
require 'dm-migrations'

# Initialize the Master DB
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/master.db")


class CL_TemplateReports
    include DataMapper::Resource

    property :id, Serial
    property :consultant_name, String, :required => false, :length => 200
    property :consultant_company, String, :required => false, :length => 200
    property :consultant_phone, String
    property :consultant_email, String, :required => false, :length => 200
    property :contact_name, String, :required => false, :length => 200
    property :contact_phone, String
    property :contact_email, String
    property :contact_city, String
    property :contact_address, String
    property :contact_zip, String
    property :full_company_name, String, :required => true, :length => 200
    property :short_company_name, String, :required => true, :length => 200
    property :company_website, String

end


class CL_Reports
    include DataMapper::Resource

    property :pId, Serial
    property :pDate, String, :length => 20
    property :pReport_type, String, :length => 200
    property :pReport_name, String, :length => 200
    property :pConsultant_name, String, :length => 200
    property :pConsultant_company, String, :length => 200
    property :pConsultant_phone, String
    property :pConsultant_title, String, :length => 200
    property :pConsultant_email, String, :length => 200
    property :pContact_name, String, :length => 200
    property :pContact_phone, String
    property :pContact_title, String, :length => 200
    property :pContact_email, String, :length => 200
    property :pContact_city, String
    property :pContact_address, String, :length => 200
    property :pContact_state, String
    property :pContact_zip, String
    property :pFull_company_name, String, :length => 200
    property :pChort_company_name, String, :length => 200
    property :pCompany_website, String, :length => 200
    property :pOwner, String, :length => 200
    property :pAuthors, CommaSeparatedList, :required => false, :lazy => false
    property :pUser_defined_variables, String, :length => 10000

end


class CL_Xslt
    include DataMapper::Resource

    property :id, Serial
    property :docx_location, String, :length => 400
    property :description, String, :length => 400
    property :xslt_location, String, :length => 400
    property :report_type, String, :length => 400
    property :finding_template, Boolean, :required => false, :default => false
    property :status_template, Boolean, :required => false, :default => false

end

DataMapper.finalize

# any differences between the data store and the data model should be fixed by this
#   As discussed in http://datamapper.org/why.html it is limited. Hopefully we never create conflicts.
DataMapper.auto_upgrade!
