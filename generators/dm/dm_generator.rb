require File.join(File.dirname(__FILE__), '../../lib/dm')

class DmGenerator < DM::ExtendedNamedBase	
	def manifest
    record do |manifest|
      locale = "en"
      
      models.each do |m|
        # Give the model a reference to the manifest
        m.manifest = manifest
        
        # Check for class naming collisions.
        manifest.class_collisions( m.controller_class_path, "#{m.controller_class_name}Controller")
        manifest.class_collisions( m.controller_class_path, "#{m.controller_class_name}Helper")
        manifest.class_collisions( m.class_path, m.class_name)                                 
      
        # Controller, helper, views, and test directories.
        manifest.directory( File.join('app/controllers',    m.controller_class_path) )
        manifest.directory( File.join('app/models',         m.class_path) )
        manifest.directory( File.join('app/observers',      m.class_path) )
        manifest.directory( File.join('app/mailers',        m.class_path) )
        manifest.directory( File.join('app/views',          m.controller_class_path, m.plural_name) )
        manifest.directory( File.join('app/helpers',        m.controller_class_path) )
        manifest.directory( File.join('public/stylesheets', m.class_path) )
        
        # 
        
        
        # manifest.directory(File.join("#{test_suffix}/functional",  m.controller_class_path))
        # manifest.directory(File.join("#{test_suffix}/models",        m.class_path))
        manifest.directory( File.join("test/fixtures",    m.class_path))

        m.migration_template( find_template_for('migration.rb'), 'db/migrate')
        m.habtm_migration_template( find_template_for('habtm_migration.rb'), 'db/migrate')

        # # Generate controller, model and helper
        # m.template( find_template_for('controller_test.rb' ), File.join('test/functional') )
        m.template( find_template_for('controller.rb'),         File.join('app/controllers') )

        # m.template( find_template_for('model_spec.rb'),       File.join('test/unit') )
        m.template( find_template_for('model.rb'),              File.join('app/models') )
        m.template( find_template_for('observer.rb'),           File.join('app/observers') )
        m.template( find_template_for('mailer.rb'),             File.join('app/mailers') )

        m.template( find_template_for('fixtures.yml'), File.join("test/fixtures"), 
                                                      :number_of_entities => 5 )
        m.template( find_template_for('helper.rb'),           File.join('app/helpers') )

        # Generate views
        %w(index show new edit _partial _form _form_fields).each do |action|
          m.template( find_template_for("view_#{action}"), File.join('app', 'views', m.controller_class_path, m.plural_name) )
        end
      end

      # Layout and stylesheet.
      manifest.template( find_template_for('layout.html.erb'), "app/views/layouts/application.html.erb", :assigns => { :controller_class_name => "Example"})
      manifest.template( find_template_for('style.css'), 'public/stylesheets/scaffold.css')
      manifest.template( find_template_for('menu.css'), 'public/stylesheets/menu.css')
      
      # manifest.directory( File.join('config/locales',  locale) ) TODO add a line to environment.rb to include locale directory
      manifest.translate(models, File.join('config/locales/', "#{locale}-models.yml"), locale)

      manifest.routes("config/routes.rb", models_hash)

      # Copy the data model file into the config directory, so it can be editted and updated
      manifest.directory("config/dm")
      manifest.create_file(File.join("config/dm", yaml_filename), yaml_content)      
    end
  end
end
