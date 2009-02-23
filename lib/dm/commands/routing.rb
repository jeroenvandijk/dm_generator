module DM #:nodoc:
  module Generator #:nodoc:
    module Commands #:nodoc:
      
      module Create
        def routes(relative_path, models)
          logger.edit(relative_path)

          gsub_file(relative_path, 'ActionController::Routing::Routes.draw do |map|') do |match|
            match + "\n\n" + build_routes(models_hash)
          end
        end
      end

      module Destroy
        def routes(relative_path, models_hash)
          logger.edit(relative_path)

          gsub_file(relative_path, build_routes(models_hash), '')

        end
      end
      
      module List
        def routes(relative_path, contents)
        end
      end
      
      module Utilities
        def build_routes(data_model, options = {}) 
          root = options[:root] || "map"
          indent = options[:indent].to_s + "  "

          routes = []

          (data_model["models"] || {}).each_pair do |resource_name, properties|      
            resource_mapping = "#{indent}#{root}.resources :#{resource_name.pluralize}"

            if associations = properties["associations"]

              nested_routes = []
              associations.each do |association|
                nested_resource_name, type = association.to_a.flatten
                nested_routes << "  #{indent}#{resource_name}.resources :#{nested_resource_name.pluralize}" if type =~ /has_many|has_and_belongs_to_many/
              end
              routes << "#{resource_mapping} " + (nested_routes.any? ? "do |#{resource_name}|\n" + nested_routes.join("\n") + "\n#{indent}end\n" : '')
            else
              routes << "#{resource_mapping}\n"
            end
          end

          (data_model["namespaces"] || {}).each_pair do |namespace_name, scoped_data_model|

            routes << "#{indent}#{root}.namespace :#{namespace_name} do |#{namespace_name}|\n"

            routes << build_routes(scoped_data_model, :root => namespace_name, :indent => indent)

            routes << "#{indent}end\n"
          end
          
          routes.join("\n")
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