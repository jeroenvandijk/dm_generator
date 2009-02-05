module DM
  class Reader 
    attr_accessor :models_hash,
                  :options

    
    def initialize(models_hash, options = {})
      @models_hash = models_hash
      @options = options
    end

    def models
      @models ||= load_models(models_hash, options)
    end


    # The nested Model class is responsible for extracting all information for each model
    class Model
      attr_reader :class_name,
                  :class_path,
                  :controller_class_name,
                  :controller_class_path,
                  :controller_class_nesting_depth,
                  :controller_file_path,
                  :controller_file_name,
                  :model_hash,
                  :model_name,
									:singular_name,
									:plural_name,
                  :table_name,
                  :habtm_associations,
                  :attributes,
                  :namespaces,
                  :supported_associations,
                  :parent_associations,
                  :supported_association_options
                  
                      
      def initialize(model_name, model_hash, options = {})
        @singular_name = @model_name = model_name.singularize
				plural_name = @singular_name.pluralize
        @model_hash = model_hash
        
        @namespaces = options[:namespaces] || []
        @namespace_symbols = @namespaces.map {|x| ":#{x}"}
        @controller_class_nesting_depth = @namespaces.length
        
        @supported_associations = options[:supported_associations] || []
        @parent_associations = options[:parent_associations] || []
        @supported_association_options = options[:supported_association_options] || []
        
        #Inflect
        @class_name = model_name.classify
        @controller_file_name = @table_name = model_name.pluralize
        @class_path = []
        @controller_file_path = @namespaces
        @controller_class_path = @namespaces.join("/")
        @controller_class_name = ( (@namespaces.empty? ? "" : controller_class_path + "/" ) + table_name).camelize
        extract_attributes
        extract_associations
      end
    
      # TODO put all necessary attributes in the h so that it can be assigned in the templates.
      def to_h
        unless @member_hash
          @member_hash = {}
          # First add all instance methods to the hash, this should be done first 
          # before values are overriden by their own references
          my_methods.each { |method_name| @member_hash[method_name] = send(method_name) }

          # Attributes
          @member_hash[:attribute_names] = attributes.map(&:name)
          @member_hash[:boolean_attributes] = attributes.reject{|x| x.type != "boolean" }
          @member_hash[:boolean_attribute_names] = @member_hash[:boolean_attributes].map(&:name)
          @member_hash[:string_attributes] = attributes.reject{|x| not %w(string text).include? x.type }
          @member_hash[:string_attribute_names] = @member_hash[:string_attributes].map(&:name)


          # Associations
          supported_associations.each do |type|
            @member_hash["#{type}_associations"] = @associations[type]
            @member_hash["#{type}_associations_with_options"] = @associations[type].map{|x| association_with_options(x) }
            @member_hash["#{type}_association_names"] = @associations[type].map{|x| x["name"] }
          end
          
          # Add the names of parent associations
          @member_hash[:parent_names] = parent_associations.inject([]) { |names, type| @member_hash["#{type}_association_names"] }
        
          # All names should be available as symbols as well
          @member_hash.each_pair do |key, values|
            new_key = key.to_s.gsub("_names", "_symbols")
            unless new_key == key.to_s
              @member_hash[new_key] = values.map{|x| ":#{x}"}
            end
          end
        end
        @member_hash
        # raise @member_hash.to_yaml
      end
      
      # form_for should support namespaces and nested resources
  		def form_for_args
  			args = []
  			args += @namespace_symbols
  			args << "parent_object" unless @associations.empty? ## TODO only do this when make_resourceful or simular library that supports nesting is available
  			args << model_name

  			args.size == 1 ? args.first : "[#{args.join(", ")}]"
  		end

      private

        def my_methods
          self.class.instance_methods - Object.instance_methods - %w(to_h model_hash path_for)
        end
        
        def association_with_options(association)
          assoc_string = ":" + association["name"]
          supported_association_options.each do |option|
            assoc_string += ", #{option} => :#{association[option]}" if association[option]
          end
          assoc_string
        end
      
        def extract_attributes
          @attributes = []
          model_hash["attributes"].collect do |attribute|
						@attributes << DM::ExtendedGeneratedAttribute.new(attribute["name"], attribute["type"])
   				end
        end
      
        def extract_associations
          # initialize associations
          @associations = {}
          supported_associations.each {|t| @associations[t] = [] }

          # find all associations and put them in the hash
          model_hash["associations"].each_pair do |name, association|
            type = association["type"]
            @associations[type] << association.reject{|k, _| k == "type"}.merge("name" => name)
          end
          @habtm_associations = @associations["has_and_belongs_to_many"] ? 
                                  @associations["has_and_belongs_to_many"].map{|x| x["name"]} :
                                  []
        end
    end

    private 
      def load_models(hash, options = {})
        models = []
        # first handle all normal models
        if models_hash = hash["models"]
          options[:namespaces] ||= [] # model can be nested in several namespaces
          models_hash.each_pair do |model_name, model_properties|
            models << Model.new(model_name, model_properties, options)
          end
        end
      
        # go into recursion to handle the models under a namespace
        if namespaces = hash["namespaces"]
          namespaces.each_pair do |namespace, models_under_namespace|
            options[:namespaces] << namespace # append current namespace to previous namespaces
            models += load_models(models_under_namespace, options)
          end
        end
        models
      end
  
  end
  
end