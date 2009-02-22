require 'yaml'

module DM
  class Reader 
    attr_accessor :models_hash,
                  :original_hash,
                  :options,
                  :file

    def initialize(file, options = {})
      @models_hash = read_file(file)
      @options = options.merge(:file => file)
      
      # Set options for Model on Class level
      Model::Base.add_options(options)
    end

    def find_attribute_type_of_model(model, attribute, namespaces = [])
      hash = namespaces.inject(models_hash) {|current_hash, namespace| current_hash["namespaces"][namespace] }

      find_attribute_of_model_in_hash(hash, model, attribute).to_a.flatten.second
    end

    def models
      @models ||= load_models(models_hash)
    end

    private
    
      # TODO change this method because it is a bit complex due to the current structure of the yaml file
      # Try to find model and attribute in the current namespace, if not found go through namespaces
      def find_attribute_of_model_in_hash(hash, model_name, attribute_name)

        if model_hash = hash["models"] && hash["models"][model_name]

          result = (model_hash["attributes"] || []).find { |name, type| name.reject{ |key, _| key == "options"}.to_a.flatten.first == attribute_name }   # TODO this will change because the attribute list will become an hash again
          return result.reject{ |key, _| key == "options"}.to_a.flatten if result                                                                        # Remove the options part of the attribute, this will be unnecessary when the yaml structure is changed
          
        elsif namespaces = hash["namespaces"]
          namespaces.each do |namespace, namespace_hash|
            result = find_attribute_of_model_in_hash(namespace_hash, model_name, attribute_name)
            return result unless result.nil?
          end
        end
        
        # Nothing found
        nil
      end

      # Read the file which can either be an xmi or yaml file
      def read_file(file)
        extension = file.split('.').last

        raise "Models file should be of the format yml or xmi. The given file '#{file}' has an '#{extension}' extension." unless extension =~ /yml|xmi/

        begin
          @original_hash = extension == "xmi" ? XmiReader.new(file).to_h : YAML::load_file(file) 
          HashWithIndifferentAccess.new(original_hash).symbolize_keys!

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
            models << Model::Base.new(model_name, model_properties, :namespaces => namespaces, :reader => self)
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