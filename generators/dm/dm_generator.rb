require File.join(File.dirname(__FILE__), '../../lib/dm')

class DmGenerator < DM::ExtendedNamedBase	
	def manifest
    record do |manifest|
      models.each do |m|
        m.manifest = manifest
        
        # Check for class naming collisions.
        manifest.class_collisions(m.controller_class_path, "#{m.controller_class_name}Controller")
        manifest.class_collisions(m.controller_class_path, "#{m.controller_class_name}Helper")
        manifest.class_collisions(m.class_path, m.class_name)                                 
      
        # Controller, helper, views, and test directories.
        manifest.directory(File.join('app/controllers',  m.controller_class_path))
        manifest.directory(File.join('app/models',       m.class_path))
        manifest.directory(File.join('app/observers',    m.class_path))
        manifest.directory(File.join('app/mailers',    m.class_path))
        manifest.directory(File.join('app/views',        m.controller_class_path, m.plural_name))
        manifest.directory(File.join('app/helpers',      m.controller_class_path))
        # 
        # manifest.directory(File.join("#{test_suffix}/functional",  m.controller_class_path))
        # manifest.directory(File.join("#{test_suffix}/models",        m.class_path))
        manifest.directory(File.join("#{test_suffix}/fixtures",    m.class_path))

        # # Generate controller, model and helper
        m.template( find_template_for('controller.rb'),      File.join('app/controllers') )
        # m.template( find_template_for('controller_test.rb' ), File.join('test/functional') )

        m.template( find_template_for('model.rb'),           File.join('app/models') )
        # m.template( find_template_for('model_spec.rb'),        File.join('test/unit') )

        m.template( find_template_for('observer.rb'),           File.join('app/observers') )
        m.template( find_template_for('mailer.rb'),           File.join('app/mailers') )

        # m.template( find_template_for('fixtures.yml'), File.join("#{test_suffix}/fixtures"), 
        #                                               :number_of_entities => 5 )
        m.template( find_template_for('helper.rb'),           File.join('app/helpers') )

        # Generate views
        %w(index show new edit _partial _form _form_fields).each do |action|
          m.template( find_template_for("view_#{action}"), File.join('app', 'views', m.controller_class_path, m.plural_name) )
        end

        # models.each do |m|
        #         # Migrations
        # # TODO create the migrations without the timestamp hack
        # 
        #   r.migration_template(find_template_for('migration.rb'), 'db/migrate', 
        #             :assigns => { model => m}.merge( :migration_name => "Create#{m.table_name.camelize}"),
        #     :migration_file_name => "create_#{m.table_name.pluralize}")
        # 
        #   r.sleep(1) # TODO make this unnecessary
        # 
        #           m.habtm_associations.each do |habtm_assoc|
        #             habtm_pair = [m.model_name, habtm_assoc.singularize].sort
        #             habtm_table_name = habtm_pair.map{|x| x.pluralize.underscore}.join('_')
        #             migration_file_name = "create_join_table_#{habtm_table_name}.rb"
        #           
        #     r.migration_template(find_template_for('migration.rb'), 'db/migrate', 
        #               :assigns => { model => m}.merge(
        #         :migration_name => "Create#{m.table_name.camelize}",
        #         :habtm_pair => habtm_pair,
        #         :habtm_table_name => habtm_table_name),
        #       :migration_file_name => "create_#{m.table_name.pluralize}")
        # 
        #     r.sleep(1) # TODO make this unnecessary
        #           end
        #         end

        #  # TODO create the migrations without the timestamp hack
				#	if is_requested? :migrations
        #   r.template(find_template_for('migration.rb'), File.join('db/migrate', "create_#{m.table_name}.rb"), 
        #     :assigns => { model => m}.merge( :migration_name => "Create#{m.table_name.camelize}")
        #   )
        # 
        #   m.habtm_associations.each do |habtm_assoc|
        # 
        #     habtm_pair = [m.model_name, habtm_assoc.singularize].sort
        #     habtm_table_name = habtm_pair.map{|x| x.pluralize.underscore}.join('_')
        #     migration_file_name = "create_join_table_#{habtm_table_name}.rb"
        #   
        #   
        #     r.template(find_template_for('habtm_migration.rb'), File.join('db/migrate', migration_file_name),
        #       :assigns => { model => m}.merge(
        #        :migration_name => migration_file_name.camelize,
        #        :habtm_pair => habtm_pair,
        #        :habtm_table_name => habtm_table_name)
        #     )
        #   end
        # end
      
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
end
