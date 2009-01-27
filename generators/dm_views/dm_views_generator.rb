require File.join(File.dirname(__FILE__), '../../lib/dm_scaffold')

class DmViewsGenerator < DM::ExtendedNamedBase
	def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions(controller_class_path, "#{controller_class_name}Controller")
      m.class_collisions(class_path, "#{class_name}")

      # Controller, helper, views, and test directories.
      m.directory(File.join('app/helpers', controller_class_path))
      m.directory(File.join('app/views', controller_class_path, controller_file_name))

			scaffold_views.each do |action|
 				template, target_filename = find_template_for(action, :prefix => "view")
				target_filename.gsub!('partial', name) if action == '_partial'
				m.template(template, File.join('app', 'views', controller_class_path, controller_file_name, target_filename))
      end

      # Helper
      m.template(find_template_for('helper.rb'), File.join('app/helpers', controller_class_path, "#{controller_file_name}_helper.rb"))
    end
  end
end
