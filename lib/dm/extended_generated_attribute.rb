require 'rails_generator'
require 'yaml'

module DM
  # This class hide the complex logic of showing different types of attributes
  # An attribute can be simple or complex
  # Simple:
  #   This is an attribute that directly accessible from the object so is thus a (virtual) attribute or an association (which can be singular or plural)
  #
  # Complex
  #  This is an attribute that is not directly accessible but goes through scoping. This class only supports one nested level, but it could also work with a deeper nesting.
  #
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

      def initialize_formats(file)
        @formats = HashWithIndifferentAccess.new( YAML::load_file(file) ).symbolize_keys!
        @file = file

        validate_mapping
      end
      
      def validate_mapping
        obligatory_fields = [:native_type]#, :examples, :display]
                            
        formats.each_key do |format|
          obligatory_fields.each do |field|
            raise "Validation of file '#{file}' failed: field '#{field}' is not defined for format '#{format}'" unless formats[format][field]
          end
        end
      end

    end
    
    attr_reader :format, :options, :templates, :model, :association_name
    
    delegate :assign_in_template, :block_in_template, :to => :model

    def initialize(name, format, options = {})
      @name, tmp_format, @options = name, format, options
      @model = options[:model]

      super(name, extract_type(tmp_format))

      raise "Model should be defined for '#{name}:#{format}'" unless model  # TODO make this an extra argument?

      @association_name = options[:association_name]  # Now we can use attributes of other models as our attributes
      @scope = options[:scope] || []                        # Now we can use attributes of our virtual object as our attributes

    end
    
    def default
      @default ||= mapping("examples.valid") || super
    end
    
    def form_label
      assign_in_template{ "#{model.form_reference}.label :#{name}" }
    end
    
    # Handle form field for association
    def form_field_for_association
      if association = model.has_association?(name)
        
        if @meta_type == "many"
          "#{model.form_reference}.label_and_select_many :#{name}"
        
        elsif name.pluralize == name
          "#{model.form_reference}.label_and_check_boxes :#{name}"
          
        else
          "#{model.form_reference}.label_and_select_one :#{name}"
        end
      else
        raise "couldn't find association #{name} on #{model.singular_name}"
      end
    end
    
    # def form_field(template = :default)
    #   assign_in_template do
    # 
    #     if association?
    #       form_field_for_association
    # 
    #     elsif form_fieldmapping("form_field")
    #       parse_display_template(form_field_template, :form_reference => model.form_reference, :instance => model.singular_name)
    # 
    #     else # native or no mapping found
    #       puts mapping_missing_message_for("form_field", template) + " Using native form_field of type #{type}." unless native?
    #       "#{model.form_reference}.#{field_type} :#{name}"
    #       
    #     end
    #   end
    #   
    # end
    
    def form_label_and_field(template = :default)
      if association?
        assign_in_template{ form_field_for_association }

      elsif label_and_field = mapping('form.label_and_field')
        assign_in_template{ parse_display_template(label_and_field, :form_reference => model.form_reference, :instance => model.singular_name) }

      elsif field = mapping('form.field')
        form_label +
        assign_in_template{ parse_display_template(field, :form_reference => model.form_reference, :instance => model.singular_name) }
        
      else # native or no mapping found
        puts mapping_missing_message_for("form_field", template) + " Using native form_field of type #{type}." unless native?
        assign_in_template{ "#{model.form_reference}.label_and_#{field_type} :#{name}" }
        
      end
      
    end
  
    def association?
      type == "association"
    end

    # Returns true when there is no scope or when it is no association.
    def real?
      @scope.empty? && !association?
    end
  
    # Display the name of the attribute
    # For normal cases this is simple; just use the name of the attribute.
    #
    # For scope attributes we used the first element of the scope as an attribute name. Because a scope is mostly a reference
    # to an object of which we want to show a significat part. However we are not interested in that significant part (say 'name') but
    # in the actual object ('users')
    def display_name(template, options = {})
      display_of_name = "#{model.singular_name.classify}.human_attribute_name('#{@scope.empty? ? name : @scope.last}')"

      options[:no_wrapping] ? display_of_name : assign_in_template{ display_of_name }
    end
    
    def instance_and_scope_chain_and_field(template)
      instance = (template == :partial ? '' : '@') + model.singular_name
      field = @scope.empty? ? name : "try(:#{name})"
      # Field is just the name of the attribute or a scope that is tried e.g.: current_object.user.try(:first).try(:second). Note we start trying from the second scope.
      scope_chain = @scope.empty? ? nil : [@scope[0], (@scope.slice(1) || []).inject{|result, part| result << "try(:#{part})" }].compact.join(".")
      
      [instance, scope_chain, field]
    end
    

    
    
    # display returns the value of the attribute in the way it is defined in the format mapping file
    # The first argument is the symbol for the template in which we want the attribute to display
    # Arbitrary parsing can be done through the options hash, the {{key}} in the format mapping will 
    # be replaced with the key itself
    def display(template, options = {})
      instance, scope_chain, field_without_chain = instance_and_scope_chain_and_field(template)
      scoped_instance = [instance, scope_chain].compact.join(".") # use compact to remove nil elements
      field = [scoped_instance, field_without_chain].join(".")
    
      no_wrapping = options.delete(:no_wrapping)
    
      if association?
        display_of_field = "render #{field}"
        
      elsif collection?
        collection_member = @scope.last.singularize
        display_of_field = "content_tag(:ul, " + "#{scoped_instance}.inject('') {|list, #{collection_member}| list << content_tag(:li, h(#{collection_member}.#{field_without_chain}))} )"
        
      elsif display = mapping("display.#{template}") || mapping("display.default")

        display_of_field = parse_display_template( display, options.reverse_merge(:instance => instance, :field => field) )
      else
      
        puts mapping_missing_message_for(:display, template) + " Native format '#{type} is used." if !native?
      
        # Default case, using native format
        display_of_field = case type
                            when :datetime, :date : "l(#{field})"
                            when :decimal, :float : "number_with_delimiter(#{field})"
                            when :string, :text   : "h(#{field})"
                            else                                 
                              field
                            end
        
      end
      assign_in_template{ display_of_field } 
      no_wrapping ? display_of_field : assign_in_template{ display_of_field } 
    end

    private
      def mapping(path, asked_format = nil)
        asked_format ||= format

        format_definition = formats[asked_format]
        
        if format_definition
          path.to_s.split('.').inject(format_definition) do |result, k| 
            if result[k].nil?
              puts "Warning: Formats #{asked_format}.#{path} is missing, couldn't find '#{k}' part"
              return nil
            end
            result[k]
          end
        end
        
      end

      def parse_display_template(_display, options = {})
        # Clone display so we are certain we don't make permanent changes
        display = _display.clone
        
        display.gsub!("{{form_reference}}", model.form_reference)
        display.gsub!("{{attribute_name}}", name)
        display.gsub!("{{object_name}}", model.singular_name)

        options.each_pair { |key, value| display.gsub!("{{#{key}}}", value ) }
        
        display
      end
    
      def mapping_missing_message_for(type, *templates)
        "No :#{type} mapping for '#{format}' for :#{templates.to_sentence} template in mapping file '#{file}'."
      end

      def collection?
        @meta_type == "collection"
      end

      def association?
        type == :association
      end

      def native?
        native_types.has_key? format.to_sym
      end

      delegate :formats, :native_types, :file, :to => :parent
      
      def parent
        self.class
      end

      def extract_type(raw_format)
          format_str, @meta_type = raw_format.to_s.split("__")

          # Set format and make sure it is a symbol, this way we can use it later on 
          @format = format_str.to_sym
          
          # Try to find the format in our definition table
          type = formats[format] && formats[format][:native_type]
          
          if !type
            if native? || format == :association
              type = format
            else
              raise "The native_type for format '#{format}' extracted from raw format '#{raw_format}' (defined for model #{model.singular_name}) is not defined in #{file} and is also not a native rails type (#{native_types.keys.to_sentence}) "
            end
          end
          
          type
      end
  end
end