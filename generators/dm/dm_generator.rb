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
        m.directory(:controllers,      File.join('app/controllers',    m.controller_class_path) )
        m.directory(:models,           File.join('app/models',         m.class_path) )
        m.directory(:observers,        File.join('app/observers',      m.class_path) )
        m.directory(:mailers,          File.join('app/mailers',        m.class_path) )
        m.directory(:views,            File.join('app/views',          m.controller_class_path, m.plural_name) )
        m.directory(:helpers,          File.join('app/helpers',        m.controller_class_path) )
        m.directory(:stylesheets,      File.join('public/stylesheets', m.class_path) )
        m.directory(:controller_tests, File.join("spec/controllers",   m.controller_class_path))
        m.directory(:model_specs,      File.join("spec/models",        m.class_path))
        m.directory(:fixtures,         File.join("spec/fixtures",      m.class_path))

        m.migration_template( find_template_for('migration.rb'), 'db/migrate')
        m.habtm_migration_template( find_template_for('habtm_migration.rb'), 'db/migrate')

        # # Generate controller, model and helper
        # m.template( find_template_for('controller_spec.rb' ), File.join('spec/controllers') )
        m.template( find_template_for('controller.rb'),         File.join('app/controllers') )

        m.template( find_template_for('model_spec.rb'),       File.join('spec/models') )
        m.template( find_template_for('model.rb'),              File.join('app/models') )
        m.template( find_template_for('observer.rb'),           File.join('app/observers') )
        m.template( find_template_for('mailer.rb'),             File.join('app/mailers') )

        m.template( find_template_for('fixtures.yml'), File.join("spec/fixtures"), 
                                                      :number_of_entities => 5 )
        m.template( find_template_for('helper.rb'),           File.join('app/helpers') )

        # Generate views
        %w(index show new edit _partial _form _form_fields).each do |action|
          m.template( find_template_for("view_#{action}"), File.join('app', 'views', m.controller_class_path, m.plural_name) )
        end
      end

      # Layout and stylesheet, eye candy.
      # manifest.template( find_template_for('layout.html.erb'), "app/views/layouts/application.html.erb", :assigns => { :controller_class_name => "Example"})

      # manifest.template( find_template_for('style.css'), 'public/stylesheets/scaffold.css')
      # manifest.template( find_template_for('menu.css'), 'public/stylesheets/menu.css')
      # manifest.template( find_template_for('application_helper.rb'), 'app/helpers/application_helper.rb')
      
      # manifest.directory( File.join('config/locales',  locale) ) TODO add a line to environment.rb to include locale directory
      manifest.translate(models, File.join('config/locales/', "#{locale}-models.yml"), locale)
      manifest.template( find_template_for('en-EN-dm-generator.yml'), "config/locales/en-EN-dm-generator.yml")

      # manifest.routes("config/routes.rb", models_hash)

      # Copy the data model file into the config directory, so it can be editted and updated
      manifest.directory("config/dm")
      manifest.create_file(File.join("config/dm", model_filename), model_file_content)    # Copy the yaml file to the dm directory  
    end
  end
end
