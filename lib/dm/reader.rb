require 'yaml'

module DM
  class Reader 
    attr_accessor :models_hash,
                  :options,
									:file

    def initialize(file, options = {})
      @models_hash = HashWithIndifferentAccess.new(YAML::load_file(file)).symbolize_keys!
      @options = options.merge(:file => file)
    end

    def models
      Model.add_options(options)
			@models ||= load_models(models_hash)
    end


    # The nested Model class is responsible for extracting all information for each model
    class Model
	
			class << self
				attr_reader :supported_associations, 
										:parent_associations,
										:supported_association_options,
										:view_templates
				
				def add_options(options = {})
	        @supported_associations = options[:supported_associations] || []
	        @parent_associations = options[:parent_associations] || []
	        @supported_association_options = options[:supported_association_options] || []
					@view_templates = options[:view_templates] || []
					@file = options[:file]
				end
			end
			
			# Delegate class 
			delegate	 	:parent_associations,
									:supported_associations, 
									:supported_association_options,
									:view_templates,
							:to => :parent
			
			def parent
				self.class
			end 
		
      attr_reader :attributes,
									:class_name,
                  :class_path,
                  :controller_class_name,
                  :controller_class_path,
                  :controller_class_nesting_depth,
                  :controller_file_path,
                  :controller_file_name,
                  :habtm_associations,
                  :model_hash,
                  :model_name,
									:namespaces,
									:plural_name,
									:singular_name,
                  :table_name
                      
      def initialize(model_name, model_hash, options = {})
        @singular_name = @model_name = model_name.singularize
				@plural_name = @singular_name.pluralize
        @model_hash = model_hash
				model_hash[:associations] ||= {}
				model_hash[:attributes] ||= {}
        
        @namespaces = options[:namespaces] || []
        @namespace_symbols = @namespaces.map {|x| ":#{x}"}
        @controller_class_nesting_depth = @namespaces.length
                
        #Inflect
        @class_name = model_name.classify
        @controller_file_name = @table_name = model_name.pluralize
        @class_path = []
        @controller_file_path = @namespaces
        @controller_class_path = @namespaces.join("/")
        @controller_class_name = ( (@namespaces.empty? ? "" : controller_class_path + "/" ) + table_name).camelize
				@templates = view_templates

        extract_attributes
        extract_associations
      end
    
      # TODO put all necessary attributes in the h so that it can be assigned in the templates.
      def to_h
        # unless @member_hash
          @member_hash = HashWithIndifferentAccess.new

          # First add all instance methods to the hash, this should be done first 
          # before values are overriden by their own references
	        my_methods.each do |method_name| 
						@member_hash[method_name] = send(method_name) 
					end
	
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
            @member_hash["#{type}_association_names"] = @associations[type].map{|x| x[:name] }
          end

          # Add the names of parent associations
          @member_hash[:parent_names] = parent_associations.inject([]) { |names, type| @member_hash["#{type}_association_names"] }

					# Add special member 
					@attributes_for.each_pair {|template, attributes| @member_hash["attributes_for_#{template}"] = attributes }

          # All names should be available as symbols as well
          @member_hash.each_pair do |key, values|
            new_key = key.to_s.gsub("_names", "_symbols")
            unless new_key == key.to_s
              @member_hash[new_key] = values.map{|x| ":#{x}"}
            end
          end
        # end
        @member_hash

				# raise @member_hash.keys.to_yaml
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
          self.class.public_instance_methods - (Object.instance_methods + %w(to_h model_hash path_for my_methods))
        end
        
        def association_with_options(association)
          assoc_string = ":" + association[:name]
          supported_association_options.each do |option|
            assoc_string += ", #{option} => :#{association[option]}" if association[option]
          end
          assoc_string
        end

				# Attributes can have options, define what should be done with them here:
				def generate_attribute_options(args)
					options = HashWithIndifferentAccess.new
					if args[:only]
						options[:templates] = view_templates & args[:only]			# intersect the whitelist with the 
					elsif args[:except]
						options[:templates] = view_templates - args[:except] 		# extract the exceptions from the default templates
					end

					options
					
					# TODO other options?
				end

				# Expects a hash of length 1 or 2, in which the second argument is a options hash
				# Return the name, type and options of a yaml field
				def extract_options(field)
					field_options = HashWithIndifferentAccess.new
					if field.size == 2
						if field[:options] && field[:options].is_a?(Hash)
							field_options = yield(field.delete(:options))
						else
							raise "#{field.inspect} in model #{model_name} in #{file} has two elements, but has no options hash"	
						end

					elsif field.size != 1
						raise "wrong number of fields for field #{field.inspect} in model #{model_name} in #{file}. Should have 1 name, type key-value pair, and an options hash is.. yup optional"
					end
					[field.to_a, field_options].flatten
				end
				
        def extract_attributes
          @attributes = []
          model_hash[:attributes].collect do |attribute|

						name, type, attribute_options = extract_options(attribute) do |options|
							# raise generate_attribute_options(options).inspect if model_name 
							generate_attribute_options(options)
						end

						attribute_options[:templates] ||= view_templates

						@attributes << DM::ExtendedGeneratedAttribute.new(name, type, attribute_options)
   				end

					@attributes_for = {}
					view_templates.each do |template|
						@attributes_for[template] = attributes.reject{|x| not x.templates.include? template.to_s }
					end
        end
      
				def extract_associations
					@associations = HashWithIndifferentAccess.new
					supported_associations.each {|t| @associations[t] = [] }
          
          model_hash[:associations].collect do |association|
						name, type, association_options = extract_options(association) { |options| options }
						@associations[type] << association_options.merge(:name => name)
   				end
					
					@habtm_associations = @associations[:has_and_belongs_to_many] ? 
                                  @associations[:has_and_belongs_to_many].map{|x| x[:name]} :
                                  []

					# raise @associations.inspec
				end
    end

    private 
      def load_models(hash, namespaces = [])
        models = []
        # first handle all normal models
        if models_hash = hash["models"]
          models_hash.each_pair do |model_name, model_properties|
            models << Model.new(model_name, model_properties, :namespaces => namespaces)
          end
        end
      
        # go into recursion to handle the models under a namespace
        if found_namespaces = hash["namespaces"]
          found_namespaces.each_pair do |namespace, models_under_namespace|
            models += load_models(models_under_namespace, namespaces << namespace)
          end
        end
        models
      end
  
  end
  
end