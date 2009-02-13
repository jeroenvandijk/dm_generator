module DM
	# Model class is responsible for extracting all information for each model
 class Model
	
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
		delegate	 	:parent_associations,
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
                :habtm_associations,
                :model_hash,
                :namespaces,
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
 
    # TODO add api comments

    def form_reference;     "f"; end

    def define_helper;      "module #{controller_class_name}Helper" + (block_given? ? yield.to_s : "") + "\nend"; end
    def define_observer;    "def #{class_name}Observer" + (block_given? ? yield.to_s : "") + "\nend"; end
    def define_mailer;      "class #{controller_class_name}Mailer < ActionMailer::Base" + (block_given? ? yield.to_s : "") + "\nend"; end
    def define_controller;  "class #{controller_class_name}Controller < ApplicationController" + (block_given? ? yield.to_s : "") + "\nend"; end
    def define_model;       "class #{class_name} < ActiveRecord::Base" + (block_given? ? yield.to_s : "") + "\nend"; end
    def make_resourceful;   "make_resourceful do\n#{indent * 2}actions :all\n"+ (has_parents? ? "#{indent * 2}belongs_to: #{parents.join(',')}\n" : '') + "#{indent}end"; end

    def form_for;           block_in_template{ "form_for #{form_for_args} do |#{form_reference}|" } + (block_given? ? yield.to_s : "") + "\n#{block_in_template{"end"}}"; end

    def form_for_args
      args = namespaces + (has_parent? ? ["parent_object"] : []) + [singular_name]
      args.size == 1 ? args.first : args
    end
 
    # Render partial exploits the new rails render feature:
    # - render @article  # Equivalent of render :partial => 'articles/_article', :object => @article
    # - render @articles # Equivalent of render :partial => 'articles/_article', :collection => @articles  
    def render_partial(objects)
     assign_in_template { "render #{objects}" }
    end

    def render_form
      assign_in_template { "render :partial => :form, :locals => {:#{singular_name} => #{singular_name} }" }
    end

    # Render form use the field_for template too include the form of the nested object
    def render_fields_for(object)
      assign_in_template { "#{form_reference}.fields_for {|#{form_reference}| render :partial => '#{object.pluralize}/fields_for', :locals => {:#{form_reference} => #{form_reference}} }"  }
    end

    def has_parent?
      @has_parent ||= nil #associations.inject(false) { |result, association| result || association.child? }
    end

    # def m_r_link_to(action, text)
    #   case action
    #   when
    #     
    #   end
    # end

    def link_to(action, options = {}) 
      type = options[:type] || "path"
      partial = options[:partial] || "default"
      instance = partial == "partial" ? singular_name : "@#{singular_name}"
    
      assign_in_template do
        "link_to translate_for('#{singular_name}.#{partial}.link_to_#{action}'), " +
        case action 
        when :new      : "new_#{singular_name}_#{type}"
        when :edit     : "edit_#{singular_name}_#{type}(#{instance})"
        when :destroy  : "#{instance}, :confirm => translate_for('#{singular_name}.#{partial}.confirm_destroy_message'), :method => :delete"
        when :index    : "#{plural_name}_path"
        when :show     : "#{instance}"
        end
      end
    end
    
    def manifest=(manifest)
      @manifest = manifest
    end

    def template_should_be_generated?(template)
      default = DM::Model.template_should_be_generated?(template)

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

    # TODO write how this can be overwritten so that it can be used for haml
    def block_in_template;                "<% " + yield + " %>"; end
    def assign_in_template;               "<%= " + yield + " %>"; end


    def indent
      "\t"
    end

    def parents
      @parents ||= associations.reject { |association| not association.is_parent_relation? }.map{|x| ":#{x.singularize}" }
    end

    def has_parents?
      parents.empty?
    end

    def has_attribute?(name)
      attributes.inject(false) { |result, attribute| result || attribute.name == name.to_s }
    end

    def attributes_for(template)
      @attributes_for ||= {}
      @attributes_for[template] ||= attributes.reject{|x| not x.templates.include? template.to_s }
    end

    def associations_for(template)
      @attributes_for ||= {}
      @attributes_for[template] ||= associations.reject{|x| not x.templates.include? template.to_s }
    end


    # translations
    def page_title(action = "default")
      assign_in_template{ "@page_title = translate_for('#{singular_name}.#{action}.title')" }
    end
    
    def save_form_button
      assign_in_template { "#{form_reference}.submit translate_save_for(:#{singular_name})" }
    end
    
    def error_messages
      assign_in_template { "#{form_reference}.error_messages" }
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
      [field.to_a, field_options || {}].flatten
    end
    
  end
end