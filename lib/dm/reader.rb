require 'yaml'

module DM
  class Reader 
    attr_accessor :models_hash,
                  :options,
									:yaml_file

    def initialize(yaml_file, options = {})
      begin
				@models_hash = HashWithIndifferentAccess.new(YAML::load_file(yaml_file)).symbolize_keys!
			rescue StandardError => e
				raise "Models yaml file could not be loaded: #{e}"
			end
      @options = options.merge(:yaml_file => yaml_file)
			Model::Base.add_options(options)
    end

    def models
			@models ||= load_models(models_hash)
    end

    private 
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