module DM #:nodoc:
  module Generator #:nodoc:
    module Commands #:nodoc:
      
      module Create
        def create_file(relative_path, content)
          path = destination_path(relative_path)
          
          logger.create(path) { File.open(path, 'wb') { |file| file.write( content ) } }
        end
      end

      module Destroy
        def create_file(relative_path, content)
          path = destination_path(relative_path)
          
          if File.exists?(path)
            logger.rm(relative_path) do
              File.delete(path)
            end
          end
        end
      end
      
      module List
        def create_file(path, contents)
        end
      end              
    end
  end
end

%w(Create Destroy List).each do |action|
  eval("DM::Generator::Commands::#{action}").send :include, DM::Generator::Commands::Utilities
end

Rails::Generator::Commands::Create.send   :include,  DM::Generator::Commands::Create
Rails::Generator::Commands::Destroy.send  :include,  DM::Generator::Commands::Destroy
Rails::Generator::Commands::List.send     :include,  DM::Generator::Commands::List