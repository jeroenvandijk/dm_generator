require File.dirname(__FILE__) + '/model/helpers'
require File.dirname(__FILE__) + '/model/associations'
require File.dirname(__FILE__) + '/model/specifications'

module DM
  module Model
    # Base class is responsible for extracting all information for each model
    class Base
      include Model::Helpers
      include Model::Associations
			include Model::Specifications

      class << self
        attr_accessor :generator, :template_settings, :directories_created
        
        delegate :indention_style, :model_filename, :template_should_be_generated?, :to => :generator
      end

      delegate    :indention_style, :model_filename, :directories_created, :to => :parent
      delegate    :find_attribute_type_of_model, :to => :reader     # TODO is this really used?
    
      def parent
        self.class
      end 
  
      attr_reader :attributes,
                  :associations,
                  :class_name,
                  :class_path,
                  :controller_class_name,
                  :controller_class_path,
                  :controller_class_nesting_depth,
                  :controller_file_path,
                  :controller_file_name,
                  :file_name,
                  :model_hash,
                  :options,
                  :namespaces,
                  :namespace_symbols,
                  :plural_name,
                  :reader,                                               # TODO Really necessary?, only used in one delegate
                  :singular_name


      # model_name is assumed to be singular since it defines
      # the models (which are singular)
      def initialize(name, property_hash, runtime_options = {}) #nodoc
         @plural_name = name.pluralize
         @singular_name = plural_name.singularize
         @file_name = singular_name.underscore
        
         @model_hash = HashWithIndifferentAccess.new(property_hash).symbolize_keys!

         raise "Model #{singular_name} should have attributes or associations can be left empty in #{model_filename}" unless model_hash

         @namespaces = runtime_options[:namespaces] || []
         @reader = runtime_options[:reader]                             # TODO Really necessary?, only one delegate
         
         @namespace_symbols = @namespaces.map {|x| ":#{x}"}
         @controller_class_nesting_depth = @namespaces.length           # TODO where am I using this. Probably in tests which are not yet generatable

         #Inflect
         @class_name = singular_name.classify
         @controller_file_name = plural_name
         @class_path = []
         @controller_file_path = @namespaces

         @controller_class_path = File.join(@namespaces.join('/'))

         @controller_class_name = ( (@namespaces.empty? ? "" : controller_class_path + "/" ) + plural_name).camelize

         @options = model_hash[:options] || {}
         @files_to_include = options[:include]
         @files_to_exclude = options[:only]

         @attributes = (model_hash[:attributes] || []).collect { |attribute| DM::ExtendedGeneratedAttribute.new( *extract_name_type_and_options(attribute, :model => self) ) }
         @associations = (model_hash[:associations] || []).collect { |association| DM::Association.new( *extract_name_type_and_options(association) ) }

      end

      def manifest=(manifest)
        @manifest = manifest
      end

      def template_should_be_generated?(raw_template_name)
        template = raw_template_name.to_s.slice(/view/) ? "views" : raw_template_name.to_s.dup

        self.class.template_should_be_generated?(template, :files_to_include => @files_to_include, 
                                                           :files_to_exclude => @files_to_exclude)
      end

			# Wrapper method to skip certain directories and prevent double checks plus logs
			def directory(*args)
				template_type = args.shift # removes the first argument as well
				template_path = args.first
				self.class.directories_created ||= {}

				# Only execute the directory call when we haven't done this before and the result was POSITIVE (meaning the directory has been created)
				# If it was negative it is still possible that there the current model decides that the directory should be created
				unless self.class.directories_created[template_path]
					if template_should_be_generated?(template_type)
						self.class.directories_created[template_path] = true
						@manifest.directory(*args) 
					end
				end
			end

			# Wrapper method to skip certain directories and prevent double checks plus logs
      def template(template, base_path, options = {})
        target_file = File.basename(template, ".erb")
        type, extension = target_file.split('.', 2)
      
        filename_suffix = type
      
        test_extension, test_type  = type.reverse.split('_', 2)
        if %w(spec test).include?(test_extension)
          filename_suffix = test_type
          extension = "_#{test_extension}.#{extension}"
        end

        # only create the template if it is not in the exclude list
        if template_should_be_generated? filename_suffix
          filename =  case type 
                      when "controller", "helper"           : File.join(controller_class_path, "#{controller_file_name}_#{filename_suffix}")
                      when 'model'                          : singular_name
											when /model_(spec|test)/              : "#{singular_name}_spec"
                      when 'observer',  'mailer'            : "#{singular_name}_#{filename_suffix}"
                      when 'fixtures'                       : plural_name
                      when 'view__partial'                  : "_#{singular_name}"  
                      when /view_.*/                        : type.gsub('view_', '')
                      end + ".#{extension}"
                    
          @manifest.template(template, File.join(base_path, filename), :assigns => options.merge(:model => self))
        end
      end
      
      def migration_template(template, path, options = {})
        # raise template_should_be_generated?("migrations").inspect
				if template_should_be_generated?("migrations")        
          options[:assigns]             ||= { :model => self, :migration_name => "Create#{plural_name.camelize}" }
          options[:migration_file_name] ||= "create_#{plural_name}"
                                
          @manifest.migration_template(template, path, options)
        end
      end
      
      
      def habtm_migration_template(template, path)
        habtm_associations.each do |habtm_assoc|
          habtm_pair = [singular_name, habtm_assoc.name.singularize].sort
          habtm_table_name = habtm_pair.map{|x| x.pluralize.underscore}.join('_')

          migration_template( template, 
                              path, 
                              :migration_file_name => "create_#{habtm_table_name}",
                              :rescue_when_already_exists => true,
                              :assigns => { :model => self,
                                            :migration_name => "Create#{habtm_table_name.camelize}",
                                            :habtm_pair => habtm_pair,
                                            :habtm_table_name => habtm_table_name} )
        end
      end

      # Indention can be set by changing indention style
      def indent(level = 1)
        indention_style * level
      end

      def has_association?(name)
        # associations.inject(false) { |result, association| result || association.name.singularize == name.to_s }
        associations.find { |x| x.name.singularize == name.to_s.singularize }
      end

      def has_attribute?(name)
        attributes.inject(false) { |result, attribute| result || attribute.name == name.to_s }
      end

      # Make sure _partial are recognized
      def format_template_name(template_name)
        template_name.to_s.gsub('_', '')
      end

			# Abstraction of form attributes
			def attributes_for_form(_template)
				template = _template.to_s  #TODO 
			end
			

      # Attributes come in two categories:
      #  - simple (String)
      #     a defined attribute
      #     a defined association
      #     a virtual attribute without type (defaults to string)
      #  - complex (Hash)
      #    a virtual attribute with a certain type
      #    an attribute of an association with a certain type
      #
      def load_attributes_for(template)
        if options[:attributes_for] && options[:attributes_for][template] 
          options[:attributes_for][template].collect do |attribute_name_or_hash|
          
            if attribute_name_or_hash.is_a?(String)
              find_attribute_in_attributes_or_associations(attribute_name_or_hash) || define_attribute_from_hash(attribute_name_or_hash => "string")
            
            elsif attribute_name_or_hash.is_a?(Hash)
              define_attribute_from_hash(attribute_name_or_hash)
          
            else
              raise "Attribute name '#{attribute_name_or_hash}' given in '#{file_name}' for model '#{singular_name}' is neither an attribute nor an association."
            end
        
          end
        else
          attributes
        end
      end
      
      # Find attributes or association from the definition of the model.
      def find_attribute_in_attributes_or_associations(attribute_name)
        attribute = attributes.find { |x| x.name == attribute_name }
        attribute ||= ExtendedGeneratedAttribute.new(attribute_name, "association", :model => self) if has_association?(attribute_name)
        
        attribute
      end
      
      def define_attribute_from_hash(hash)
        argument_pair = hash.to_a.flatten
        raise "The definition of one of the attributes for '#{singular_name}' has more than two elements: (#{hash.inspect})" if argument_pair.size > 2
        
        attribute_with_scope, type = argument_pair
        raise "The definition of one of the attributes for '#{singular_name}' is not a pair of strings: (#{hash.inspect})" unless type.is_a?(String)
        
        attribute_name, *reversed_scope = attribute_with_scope.split('.').reverse
        
        raise hash.inspect if type == "namestring"
        
        ExtendedGeneratedAttribute.new(attribute_name, type, :model => self, :scope => reversed_scope.reverse)
      end
      
      def attributes_for(template)
        @attributes_for ||= HashWithIndifferentAccess.new
        @attributes_for[template] ||= load_attributes_for(template)
      end

      private
      # Expects a hash of length 1 or 2, in which the second argument is a options hash
      # Return the name, type and options of a yaml field
      def extract_name_type_and_options(field, extra_options = {})
        field_options = HashWithIndifferentAccess.new
        if field.size == 2
          raise "#{field.inspect} in model #{singular_name} in #{model_filename} is not a Hash" unless field.is_a?(Hash)

          # Extract the options by deleting it from the field
          if field[:options] && field[:options].is_a?(Hash)
            field_options = field.delete(:options)
          else
            raise "#{field.inspect} in model #{singular_name} in #{model_filename} has two elements, but has no options hash"  
          end

        elsif field.size != 1
          raise "wrong number of fields for field #{field.inspect} in model #{singular_name} in #{model_filename}. Should have 1 name, type key-value pair, and an options hash is.. yup optional"
        end
        [field.to_a, field_options.merge(extra_options) || extra_options].flatten
      end
    end
  end
end