require File.join(File.dirname(__FILE__), '../../lib/dm')

class DmGenerator < DM::ExtendedNamedBase	
	def manifest
    record do |r|
      models.each do |m|
        # Set the current model so we can access the members from other places
        self.current_model = m
        
				# raise m.to_h.inspect.gsub(',', "\n") if m.model_name == "product"

        # Check for class naming collisions.
        r.class_collisions(m.controller_class_path, "#{m.controller_class_name}Controller") if is_requested? :controllers
        r.class_collisions(m.controller_class_path, "#{m.controller_class_name}Helper")     if is_requested? :helpers
        r.class_collisions(m.class_path, m.class_name) if is_requested? :models
      
        # Controller, helper, views, and test directories.
        r.directory(File.join('app/controllers',  m.controller_class_path))                 if is_requested? :controllers
        r.directory(File.join('app/models',       m.class_path))                            if is_requested? :models
        r.directory(File.join('app/views',        m.controller_class_path, m.table_name))   if is_requested? :views
        r.directory(File.join('app/helpers',      m.controller_class_path))                 if is_requested? :helpers

        r.directory(File.join('test/functional',  m.controller_class_path))                 if is_requested? :integration_tests
        r.directory(File.join('test/unit',        m.class_path))                            if is_requested? :unit_tests
        r.directory(File.join('test/fixtures',    m.controller_class_path))                 if is_requested? :fixtures

        # # Generate controller, model and helper
        r.template(find_template_for('controller.rb'      ), File.join('app/controllers', 
                                                                        m.controller_class_path, 
                                                                        "#{m.controller_file_name}_controller.rb"), 
                                                             :assigns => m.to_h)            if is_requested? :controllers
                                                             
        r.template(find_template_for('model.rb'           ), File.join('app/models', 
                                                                        "#{m.model_name}.rb"),
                                                             :assigns => m.to_h)            if is_requested? :models
                                                             
        r.template(find_template_for('helper.rb'          ), File.join('app/helpers', 
                                                                        m.controller_class_path, 
                                                                        "#{m.table_name}_helper.rb"), 
                                                            :assigns => m.to_h)             if is_requested? :helpers
    
        # Generate views
        if is_requested? :views
          scaffold_views.each do |action|
            template, target_filename = find_template_for(action, :prefix => "view")
            target_filename.gsub!('partial', m.model_name) if action == '_partial'
            r.template(template, File.join('app', 'views', m.controller_class_path, m.table_name, target_filename), :assigns => m.to_h)
          end
        end
          
        # Generate tests and fixtures
        r.template(find_template_for('functional_test.rb' ), File.join('test/functional', 
                                                                        m.controller_class_path,
                                                                        "#{m.table_name}_controller_test.rb"),
                                                            :assigns => m.to_h)             if is_requested? :integration_tests
                                                            
        r.template(find_template_for('unit_test.rb'       ), File.join('test/unit', 
                                                                        m.class_path,
                                                                        "#{m.model_name}_test.rb"),
                                                            :assigns => m.to_h)             if is_requested? :unit_tests
                                                            
        r.template(find_template_for('fixtures.yml'       ), File.join('test/fixtures', 
                                                                      "#{m.table_name}.yml"), 
                                                             :assigns => m.to_h.merge( :number_of_entities => 5 )) if is_requested? :fixtures
          
        # Migrations
        if is_requested? :migrations
          r.template(find_template_for('migration.rb'), File.join('db/migrate', "create_#{m.table_name}.rb"), 
            :assigns => m.to_h.merge( :migration_name => "Create#{m.table_name.camelize}")
          )
        
          m.habtm_associations.each do |habtm_assoc|
        
            habtm_pair = [m.model_name, habtm_assoc.singularize].sort
            habtm_table_name = habtm_pair.map{|x| x.pluralize.underscore}.join('_')
            migration_file_name = "create_join_table_#{habtm_table_name}.rb"
          
          
            r.template(find_template_for('habtm_migration.rb'), File.join('db/migrate', migration_file_name),
              :assigns => m.to_h.merge(
               :migration_name => migration_file_name.camelize,
               :habtm_pair => habtm_pair,
               :habtm_table_name => habtm_table_name)
            )
          end
        end
      
      # 
      # # Generate routes
      # # TODO routes should be generate at once given all resources. This saves many unnecessary regular expression, or not?
      # # Do something with models here!
      # # r.routes_nested_resources name, parent_names, "\t"       if is_requested? :routes
      # 
      # 
      end
    end
  end
  
  # Copied from the rails core, unfortunately the migration_exists? in the manifest does not work as expected
  def migration_exists?(file_name)
    not Dir.glob("db/migrate/[0-9]*_*.rb").grep(/[0-9]+_#{file_name}.rb$/).empty?
  end
end
