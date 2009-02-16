module DM
  module Model
    module MigrationsPatch

      def self.included(base)
        base.alias_method_chain :next_migration_string, :follow_up
        base.alias_method_chain :migration_template, :rescue
      end

      # The Rails Generator isn't made to do batch migrations
      # This is a patch to do batch migrations
      def next_migration_string_with_follow_up(padding = 3)
        if ActiveRecord::Base.timestamped_migrations
          @next_migration_string ||= Time.now.utc.strftime("%Y%m%d%H%M%S")
          @next_migration_string = (@next_migration_string.to_i + 1).to_s
        else
          "%.#{padding}d" % next_migration_number
        end
        
      end
      
      
      # The Rails Generator creates an exceptions when a migration already exist
      # This is a problem when you are not sure whether a table already exists for
      # example in the case of the habtm association. So this is a path with a rescue option
      def migration_template_with_rescue(relative_source, relative_destination, template_options = {})
        migration_directory relative_destination
        migration_file_name = template_options[:migration_file_name] || file_name
        if migration_exists?(migration_file_name)
          if template_options[:rescue_when_already_exists]
            logger.exists "#{relative_destination}/#{migration_file_name}.rb"
            return
          else
            raise "Another migration is already named #{migration_file_name}: #{existing_migrations(migration_file_name).first}"
          end
        end
        template(relative_source, "#{relative_destination}/#{next_migration_string}_#{migration_file_name}.rb", template_options)
      end
    
    end
  end
end
      
Rails::Generator::Commands::Create.send   :include,  DM::Model::MigrationsPatch
