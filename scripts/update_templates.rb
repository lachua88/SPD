require 'rubygems'
require './model/master.rb'

findings = CL_Library_finding.all

findings.each do |finding|
     finding["approved"] = true
     finding.save 	
end
