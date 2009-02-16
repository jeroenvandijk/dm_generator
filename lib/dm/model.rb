require File.dirname(__FILE__) + '/model/helpers'
require File.dirname(__FILE__) + '/model/associations'

module DM
  module Model
    # Base class is responsible for extracting all information for each model
    class Base
      include DM::Model::Helpers
      include DM::Model::Associations

      class << self
        attr_reader :supported_associations, 
                    :parent_associations,
                    :supported_association_options,
                    :view_templates,
                    :yaml_file,
                    :collection_associations

        attr_accessor :file_instructions

        def add_options(options = {})
         @supported_associations = options[:supported_associations] || []
         @parent_associations = options[:parent_associations] || []
         @supported_association_options = options[:supported_association_options] || []
          @view_templates = options[:view_templates] || []
          @yaml_file = options[:yaml_file]
          @collection_associations = %w(has_many has_and_belongs_to_many)
        end


        def template_settings
            @template_settings ||= {
              :views            => { :abbreviation => :v },
              :model            => { :abbreviation => :m },
              :controller       => { :abbreviation => :c },
              :helper           => { :abbreviation => :h, :exclude_by_default => true },
              :fixtures         => { :abbreviation => :f },
              :routes           => { :abbreviation => :r },
              :migrations       => { :abbreviation => :d },
              :controller_test  => { :abbreviation => :i },
              :model_test       => { :abbreviation => :u },
              :mailer           => { :abbreviation => :e, :exclude_by_default => true },
              :observer         => { :abbreviation => :o, :exclude_by_default => true },
              :language_file    => { :abbreviation => :l }
            }
        end

        def template_from_mapping(abbreviation)
          template_settings.each_pair do |template, settings|
            return template if settings[:abbreviation] == abbreviation
          end
        end

        def template_should_be_generated?(type)
          default = !(template_settings[type] && template_settings[type][:exclude_by_default])

          if default
            file_instructions[:files_to_ignore].nil? ||
            file_instructions[:files_to_ignore].inject(true) { |result, abbreviation| result && type != template_from_mapping(abbreviation) }
          else
            file_instructions[:files_to_include] &&
            file_instructions[:files_to_include].inject(false) { |result, abbreviation| result || type == template_from_mapping(abbreviation) }
          end

        end
      end
    
      # Delegate class 
      delegate    :parent_associations,
                  :supported_associations, 
                  :supported_association_options,
                  :view_templates,
                  :yaml_file,
                  :collection_associations,
              :to => :parent
    
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
                  :namespaces,
                  :namespace_symbols,
                  :plural_name,
                  :singular_name,
                  :table_name,
                  :files_to_include,
                  :files_to_exclude

      # model_name is assumed to be singular since it defines
      # the models (which are singular)
      def initialize(model_name, model_hash, options = {}) #nodoc
         @plural_name = model_name.pluralize
         @singular_name = plural_name.singularize
         @file_name = singular_name.underscore
        
         @files_to_include = options[:include] || []
         @files_to_exclude = options[:only] || []

         @model_hash = HashWithIndifferentAccess.new(model_hash).symbolize_keys!

         raise "Model #{model_name} should have attributes or associations can be left empty in #{yaml_file}" unless model_hash

         @namespaces = options[:namespaces] || []
         @namespace_symbols = @namespaces.map {|x| ":#{x}"}
         @controller_class_nesting_depth = @namespaces.length

         #Inflect
         @class_name = singular_name.classify
         @controller_file_name = @table_name = model_name.pluralize
         @class_path = []
         @controller_file_path = @namespaces

         @controller_class_path = File.join(@namespaces.join('/'))

         @controller_class_name = ( (@namespaces.empty? ? "" : controller_class_path + "/" ) + plural_name).camelize

         @attributes = (model_hash[:attributes] || []).collect { |attribute| DM::ExtendedGeneratedAttribute.new( *extract_name_type_and_options(attribute) ) }
         @associations = (model_hash[:associations] || []).collect { |association| DM::Association.new( *extract_name_type_and_options(association) ) }
      end

      def manifest=(manifest)
        @manifest = manifest
      end

      def template_should_be_generated?(template)
        default = Model::Base.template_should_be_generated?(template.to_sym)

        if default
          not files_to_exclude.include?(template)
        else
          files_to_include.include?(template)
        end            
      end

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
                      when 'observer',  'mailer'            : "#{singular_name}_#{filename_suffix}"
                      when 'fixtures'                       : plural_name
                      when 'view__partial'                  : "_#{singular_name}"  
                      when /view_.*/                        : type.gsub('view_', '')
                      end + ".#{extension}"
                    
          @manifest.template(template, File.join(base_path, filename), :assigns => options.merge(:model => self))
        end
      end
      
      def migration_template(template, path, options = {})
        if template_should_be_generated?("migration")        
          options[:assigns]             ||= { :model => self, :migration_name => "Create#{plural_name.camelize}" }
          options[:migration_file_name] ||= "create_#{plural_name}"
                                
          @manifest.migration_template(template, path, options)
        end
      end
      
      
      def habtm_migration_template(template, path)
        habtm_associations.each do |habtm_assoc|
          habtm_pair = [singular_name, habtm_assoc.name.singularize].sort
          habtm_table_name = habtm_pair.map{|x| x.pluralize.underscore}.join('_')
          migration_file_name = "create_join_table_#{habtm_table_name}.rb"
          
          migration_template( template, 
                              path, 
                              :migration_file_name => "create_#{habtm_table_name.pluralize}",
                              :rescue_when_already_exists => true,
                              :assigns => { :model => self,
                                            :migration_name => "Create#{habtm_pair.to_s.camelize}",
                                            :habtm_pair => habtm_pair,
                                            :habtm_table_name => habtm_table_name} )
        end
      end

      def indent
        "\t"
      end

      def has_attribute?(name)
        attributes.inject(false) { |result, attribute| result || attribute.name == name.to_s }
      end

      # Make sure _partial are recognized
      def format_template_name(template_name)
        template_name.to_s.gsub('_', '')
      end

      def attributes_for(_template)
        template = format_template_name(_template)
        @attributes_for ||= {}
        @attributes_for[template.to_sym] ||= attributes.reject{|x| not x.templates.include? template }
      end

      def associations_for(_template)
        template = format_template_name(_template)
        @associations_for ||= {}
        @associations_for[template.to_sym] ||= associations.reject{|x| not x.templates.include? template }
      end

      private
      # Expects a hash of length 1 or 2, in which the second argument is a options hash
      # Return the name, type and options of a yaml field
      def extract_name_type_and_options(field)
        field_options = HashWithIndifferentAccess.new
        if field.size == 2
          raise "#{field.inspect} in model #{singular_name} in #{yaml_file} is not a Hash" unless field.is_a?(Hash)

          # Extract the options by deleting it from the field
          if field[:options] && field[:options].is_a?(Hash)
            field_options = field.delete(:options)
          else
            raise "#{field.inspect} in model #{singular_name} in #{yaml_file} has two elements, but has no options hash"  
          end

        elsif field.size != 1
          raise "wrong number of fields for field #{field.inspect} in model #{singular_name} in #{yaml_file}. Should have 1 name, type key-value pair, and an options hash is.. yup optional"
        end
        [field.to_a, field_options.merge(:model => self) || {:model => self}].flatten
      end
    end
  end
end