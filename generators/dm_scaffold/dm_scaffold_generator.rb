require File.join(File.dirname(__FILE__), '../../lib/dm_scaffold')

class DmScaffoldGenerator < DM::ExtendedNamedBase
	
	def manifest
    record do |m|

      # Check for class naming collisions.
      m.class_collisions(controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}Helper")
      m.class_collisions(class_path, "#{class_name}")

			arguments = [name] + @args

			# When there is a name space we don't want to have a namespaced model so threat this differently then the views and models
			if namespace.empty?
				m.dependency 'dm_model', arguments, :collision => :skip
			else
				m.dependency 'dm_model', [class_name.demodulize.underscore] + @args
			end
		
			m.dependency 'dm_views', arguments, :collision => :skip
			m.dependency 'dm_controller', arguments, :collision => :skip
    end
  end
end
