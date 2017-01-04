require 'rubygems'
require './model/master.rb'

# This will export all findings as JSON, useful for import later

if ARGV.size > 0
  id = ARGV[0]
  puts "Exporting single finding with id #{id}"
  
  findings = CL_Library_finding.first(:pId => id)
  
  puts findings.to_json
  
else

  findings = CL_Library_finding.all

  findings.each do |f|  
    puts f.to_json
  end

end



