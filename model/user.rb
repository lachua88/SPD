require 'rubygems'
require 'data_mapper'
require 'digest/sha1'
require 'dm-migrations'

# Initialize the Master DB
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db/master.db")

class CL_User
    include DataMapper::Resource

    property :pId, Serial
    property :pUsername, String, :key => true, :length => (3..40), :required => true
    property :pHashed_password, String
    property :pSalt, String
    property :pType, String
    property :pPlugin, Boolean, :required => false, :default => false
    property :pAuth_type, String, :required => false
    property :pCreated_at, DateTime, :default => DateTime.now
    property :pConsultant_name, String, :required => false
    property :pConsultant_company, String, :required => false
    property :pConsultant_phone, String, :required => false
    property :pConsultant_email, String, :required => false
    property :pConsultant_title, String, :required => false

    attr_accessor :password
    validates_presence_of :pUsername

    def password=(pass)
        @password = pass
        self.pSalt = rand(36**12).to_s(36) unless self.pSalt
        self.pHashed_password = CL_User.encrypt(@password, self.pSalt)
    end

    def self.encrypt(pass, salt)
        
        return Digest::SHA1.hexdigest(pass + salt)
    end

    def self.authenticate(username, pass)
    user = CL_User.first(:pUsername => username)
        if user.pSalt
            return user.pUsername if CL_User.encrypt(pass, user.pSalt) == user.pHashed_password
        end
    end

end

class CL_Sessions
    include DataMapper::Resource

    property :pId, Serial
    property :pSession_key, String, :length => 128
    property :pUsername, String, :length => (3..40), :required => true

    def self.is_valid?(session_key)
        sessions = CL_Sessions.first(:pSession_key => session_key)
        return true if sessions
    end

    def self.type(session_key)
        sess = CL_Sessions.first(:pSession_key => session_key)

        if sess
            return CL_User.first(:pUsername => sess.pUsername).pType
        end
    end

    def self.get_username(session_key)
        sess = CL_Sessions.first(:pSession_key => session_key)

        if sess
            return sess.pUsername
        end
    end

    def self.is_plugin?(session_key)
        sess = CL_Sessions.first(:pSession_key => session_key)

        if sess
            return CL_User.first(:pUsername => sess.pUsername).pPlugin
        end
    end


end

DataMapper.finalize

# any differences between the data store and the data model should be fixed by this
#   As discussed in http://datamapper.org/why.html it is limited. Hopefully we never create conflicts.
DataMapper.auto_upgrade!
