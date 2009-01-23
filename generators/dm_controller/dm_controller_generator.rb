require File.join(File.dirname(__FILE__), '../../lib/dm_scaffold')

class DmControllerGenerator < DM::ExtendedNamedBase
	
	def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions(controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}Helper")
      m.class_collisions(class_path, "#{class_name}")

      # Controller, helper, views, and test directories.
      m.directory(File.join('app/controllers', controller_class_path))
      m.directory(File.join('test/functional', controller_class_path))

      # Controller
      m.template(find_template_for('controller.rb'), File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb"))      

      # Tests
      m.template(find_template_for('functional_test.rb'), File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb"))

      # Routes
			m.dependency 'dm_routes', [name] + @args, :collision => :skip
    end
  end
end