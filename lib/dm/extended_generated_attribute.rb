require 'rails_generator'
require 'yaml'

module DM
  class ExtendedGeneratedAttribute < Rails::Generator::GeneratedAttribute
    # Create a singleton method that defines the types, loaded before other things happen
    # formats
    #   :email: :string
    # 
    # examples
    #   - email: name@name.com
      
        
    def self.native_types
      @native_types ||= ActiveRecord::Base.connection.native_database_types
    end

    class << self
      attr_accessor :formats, :file

      def init_formats(file)
        @formats = HashWithIndifferentAccess.new( YAML::load_file(file) ).symbolize_keys!
        @file = file

        validate_mapping
      end
      
      def validate_mapping
        obligatory_fields = [:native_type, :examples, :display]
                            
        formats.each_key do |format|
          obligatory_fields.each do |field|
            raise "Validation of file '#{file}' failed: field '#{field}' is not defined for format '#{format}'" unless formats[format][field]
          end
        end
      end

    end
    
    attr_reader :format, :options, :templates, :model, :association_name, :scope
    
    delegate :assign_in_template, :block_in_template, :to => :model

    def initialize(name, format, options = {})
      @name, @format, @options = name, format, options
      
      super(name, extract_type(format))

      # Attributes are basically only used for index, show, form and migrations     
      @templates = %w(index show form migration)
      @templates = options[:only].map(&:to_s) & templates.map(&:to_s) if options[:only]
      @templates = templates.map(&:to_s) - options[:except].map(&:to_s) if options[:except]
      
      
     
      

      @model = options[:model]

      raise "Model should be defined for '#{name}:#{format}'" unless model

      @association_name = options[:association_name]  # Now we can use attributes of other models as our attributes
      @scope = options[:scope]                        # Now we can use attributes of our virtual object as our attributes
      

    end
    
    def default
      @default ||= mapping(:examples, :valid) || super
    end
    
    def form_label
      assign_in_template{ "#{model.form_reference}.label :#{name}" }
    end
    
    def form_field
      assign_in_template do
        if native? || !formats[format]['form_field']
          "#{model.form_reference}.#{field_type} :#{name}"
        else
          parse_display_template(formats[format]['form_field'], :form_reference => model.form_reference, :instance => model.singular_name)
        end
      end
      
    end
  
    # Gives the name of the field
    def display_name(template)
      if association_name.nil?
        # Scope is used for virtual attributes that return a reference to another model, 
        # we want to return the name of this scope because it tells more than the name of the attribute of the scoped model.
        field = scope || name                
        assign_in_template{ "#{model.class_name}.human_attribute_name('#{field}')" }
        
      else
        association_class_name = association_name.singularize.classify
        
        assign_in_template{ "#{association_class_name}.human_name + #{association_class_name}.human_attribute_name('#{name}')" }
        
      end
    end
  
    # display returns the value of the attribute in the way it is defined in the format mapping file
    # The first argument is the symbol for the template in which we want the attribute to display
    # Arbitrary parsing can be done through the options hash, the {{key}} in the format mapping will 
    # be replaced with the key itself
    def display(template, options = {})
      attribute_scope = scope || association_name
      instance = (template == :partial ? '' : '@') + model.singular_name + ( attribute_scope.nil? ? "" : ".#{attribute_scope}")
      field = attribute_scope.nil? ? "#{instance}.#{name}" : "#{instance}.try(:#{name})"

      assign_in_template do
        if native?
          case format
          when :datetime, :date : "l #{field}"
          when :decimal, :float : "number_with_delimiter #{field}"
          when :string, :text   : "h #{field}"
          else                                 
            field
          end
          
        else
          # Find the display settings from the formats hash
          display = mapping(:display, template)

          unless display
            display = mapping(:display, :default)
            puts mapping_missing_message_for(:display, template) + ", default is used." 
          end

          parse_display_template( display, options.reverse_merge(:instance => instance, :field => field) )
        end
      end
    end

    private
    
      def mapping(type, template = :default)
        formats[format] && formats[format][type] && formats[format][type][template]
      end

      def parse_display_template(_display, options = {})
        # Clone display so we are certain we don't make permanent changes
        display = _display.clone
        
        display.gsub!("{{attribute_name}}", name)

        options.each_pair { |key, value| display.gsub!("{{#{key}}}", value ) }
        
        display
      end
    
      def mapping_missing_message_for(type, template)
        "No :#{type} mapping for '#{format}' for :#{template} template in mapping file '#{file}'"
      end

      def native?
        native_types.has_key? format
      end

      delegate :formats, :native_types, :file, :to => :parent
      
      def parent
        self.class
      end

      def extract_type(_format)
        # Set format and make sure it is a symbol, this way we can use it later on 
        @format = _format.to_sym

        type = _format if native?
        type ||= formats[@format] && formats[@format][:native_type]
        raise "The native_type for format '#{format}' is not defined in #{file} and is also not a native rails type (#{native_types.keys.to_sentence}) " unless type

        type
      end
  end
end