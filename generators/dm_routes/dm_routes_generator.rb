require File.join(File.dirname(__FILE__), '../../lib/dm_scaffold')

class DmRoutesGenerator < DM::ExtendedNamedBase
	
	def manifest
    record do |m|
      # Add Routes

			m.routes_nested_resources name, parent_names, "\t"
    end
  end
end