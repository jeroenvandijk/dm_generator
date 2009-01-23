require File.join(File.dirname(__FILE__), '../../lib/dm_scaffold')

class DmModelGenerator < DM::ExtendedNamedBase
	
	def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions(class_path, "#{class_name}")

      # Controller, helper, views, and test directories.
      m.directory(File.join('app/models', class_path))
      m.directory(File.join('test/unit', class_path))
      m.directory(File.join('test/fixtures', class_path))

      # Model
      m.template(find_template_for('model.rb'), File.join('app/models', class_path, "#{file_name}.rb"))

      unless options[:skip_migration]
        m.migration_template(find_template_for('migration.rb'), 'db/migrate', 
          :assigns => {
            :migration_name => "Create#{class_name.pluralize.gsub(/::/, '')}",
            :attributes     => attributes
          },
          :migration_file_name => "create_#{file_path.gsub(/\//, '_').pluralize}")
				
				has_and_belongs_to_many_association_names.each do |habtm_assoc|
										
					habtm_pair = [name, habtm_assoc.singularize].sort
					habtm_table_name = habtm_pair.map{|x| x.pluralize.underscore}.join('_')
					migration_file_name = "create_join_table_#{habtm_table_name}"
					
					# TODO make something to prevent an error when a migration exist and that also works with destroy
					unless migration_exists?(migration_file_name)
						m.sleep(1) # Prevent name clashes in migration because of the timestamps
						m.migration_template(find_template_for('habtm_migration.rb'), 'db/migrate', 
		         :assigns => {
		           :migration_name => migration_file_name.camelize,
							 :habtm_pair => habtm_pair,
							 :habtm_table_name => habtm_table_name
          
		         },
		         :migration_file_name => migration_file_name)
					end
				end
      end

      # Tests
      m.template(find_template_for('unit_test.rb'),       File.join('test/unit', class_path, "#{file_name}_test.rb"))
      m.template(find_template_for('fixtures.yml'),       File.join('test/fixtures', "#{table_name}.yml"), :assigns => { :number_of_entities => 5 })
    end
  end

	# Copied from the rails core, unfortunately the migration_exists? in the manifest does not work as expected
  def migration_exists?(file_name)
    not Dir.glob("db/migrate/[0-9]*_*.rb").grep(/[0-9]+_#{file_name}.rb$/).empty?
  end
end
