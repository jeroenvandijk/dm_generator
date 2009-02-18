require 'yaml'

module DM
  class Reader 
    attr_accessor :models_hash,
                  :options,
                  :file

    def initialize(file, options = {})
      @models_hash = read_file(file)
      @options = options.merge(:file => file)
      
      # Set options for Model on Class level
      Model::Base.add_options(options)
    end

    def models
      @models ||= load_models(models_hash)
    end

    private 

      # Read the file which can either be an xmi or yaml file
      def read_file(file)
        extension = file.split('.').last

        raise "Models file should be of the format yml or xmi. The given file '#{file}' has an '#{extension}' extension." unless extension =~ /yml|xmi/

        begin
          HashWithIndifferentAccess.new(extension == "xmi" ? XmiReader.new(file).to_h : YAML::load_file(file) ).symbolize_keys!

        rescue StandardError => e
          raise "Models file '#{file}' could not be loaded: #{e}"
        end
      end
    
      # Go through the models hash recursively (due to supporting namespaces) and return an array with the found models
      def load_models(hash, namespaces = [])
        models = []
        
        # first handle all normal models
        if models_hash = hash["models"]
          models_hash.each_pair do |model_name, model_properties|
            models << Model::Base.new(model_name, model_properties, :namespaces => namespaces)
          end
        end
      
        # go into recursion to handle the models under a namespace
        if found_namespaces = hash["namespaces"]
          found_namespaces.each_pair do |namespace, models_under_namespace|
            models += load_models(models_under_namespace, namespaces + [namespace])
          end
        end
        models
      end  
  end
  
end