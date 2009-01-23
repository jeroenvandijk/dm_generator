require 'rails_generator'

module DM
	class ExtendedNamedBase < Rails::Generator::NamedBase
	  attr_reader   :controller_class_path,
	                :controller_file_path,
	                :controller_class_nesting,
	                :controller_class_nesting_depth,
	                :controller_class_name,
	                :controller_underscore_name,
	                :controller_plural_name
	  alias_method  :controller_file_name,  :controller_underscore_name
	  alias_method  :controller_table_name, :controller_plural_name

	  def initialize(runtime_args, runtime_options = {})
			super
  
	    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@name.pluralize)
	    @controller_class_name_without_nesting, @controller_underscore_name, @controller_plural_name = inflect_names(base_name)
  
	    if @controller_class_nesting.empty?
	      @controller_class_name = @controller_class_name_without_nesting
	    else
	      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
	    end
		
			define_dynamic_methods
		end

		def supported_associations
			%w(has_many has_one belongs_to has_and_belongs_to_many)
		end

		## UTILITY METHODS
		def define_dynamic_methods
			# Define accessors for associations
			supported_associations.each do |assoc_type|
				eval(%(
					def #{assoc_type}_associations
						@#{assoc_type}_associations ||= associations.reject{|name, prop| prop["type"] != "#{assoc_type}" || prop["through"] }
					end
					
					def #{assoc_type}_association_names
						@#{assoc_type}_association_names ||= #{assoc_type}_associations.keys
					end
					
					def #{assoc_type}_association_symbols
						@#{assoc_type}_association_symbols ||= #{assoc_type}_association_names.map{|x| ":\#{x}"}
					 end
				))
			end
		end
		
		def has_many_through_association_names
			@has_many_through_association_names ||= associations.reject{|name, prop| !(prop["type"] == "has_many" && prop["through"])}.keys
		end
		
		def has_many_through_association_symbols
			@has_many_through_association_symbols ||= has_many_through_association_names.map{|x| ":\#{x}"}
		end

		# Util method used in fixtures, does not include has_many_through
		def collection_association_names
			@collection_association_names ||= has_and_belongs_to_many_association_names + has_many_association_names
		end
		
		# Returns the names of the parents of the current object
		# Is usefull for routes and controllers and maybe for not so dry views
		# parents are belongs_to associations plus habtm relations
		def parent_names
			@parent_names ||= belongs_to_association_names + has_and_belongs_to_many_association_names + has_many_through_association_names
		end
		
		def parent_symbols
			@parent_symbols ||= parent_names.map{|x| ":#{x}"}
		end
	
	  protected
  
		## METHODS OVERRIDEN FROM SUPER CLASS
		# Almost equal to standard scaffold excepts for the introduction of associations
		def attributes
			associations
			
			@attributes ||= @args.collect do |attribute|
				Rails::Generator::GeneratedAttribute.new(*attribute.split(":"))
			end
		end

		# Should be overridden if the scaffold needs other views to be generated
	  def scaffold_views
	    %w(index show new edit _form _partial)
	  end

	  def model_name 
	    class_name.demodulize
	  end

		def banner
			generator_name = self.class.to_s.underscore.gsub("_generator", "")
			usages = []
			usages << "Usage: #{$0} #{generator_name} ModelName [field:type, field:type]"
	    usages << "Usage: #{$0} #{generator_name} ModelName [field:type, field:type, association:type[through:model_name,dependent:action]]"
			usages.join("\n")
	  end

		# NEW METHODS
		def associations
			unless @associations
				@args.reject! {|attribute| add_association(attribute) }
			end
			@associations 
		end
		
		def association_names
			@association ||= associations.keys.map{|x| ":#{x}"}
		end
	
		def all_field_names
			@all_field_names ||= association_names + attribute_names
		end
		
		def all_field_symbols
			@all_field_symbols ||= association_symbols + attribute_symbols
		end
	
		def association_model_string(assoc_name, properties)
			properties.symbolize_keys!
			association = "#{properties[:type]} :#{assoc_name}"
			association << ", :dependent => :#{properties[:dependent]}" if properties[:dependent] && !properties[:through]
			association << ", :through => :#{properties[:through]}" if properties[:through] && properties[:type] != "belongs_to"
			association
		end

		def boolean_attribute_names
			@boolean_attribute_names ||= attributes.reject{ |a| a.type != "boolean" }.map{|x| x.name.to_sym }.sort
		end
	
		def boolean_attribute_symbols
			@boolean_attribute_names ||= boolean_attribute_names.map{|x| x.to_sym }
		end
		
		def string_attribute_names
			@string_attribute_names ||= attributes.reject{ |a| a.type != "string" || a.type != "text" }.map{|x| x.name.to_sym }.sort
		end
		
		def string_attribute_symbols
			@string_attribute_symbols ||= string_attribute_names.map{|x| x.to_sym }
		end
	
		def attribute_names
			@attribute_names ||= attributes.map(&:name).sort
		end
		
		def attribute_symbols
			@attribute_symbols ||= attribute_names.map{|x| x.to_sym }
		end
	
		# Adds association and returns whether it added an association
		def add_association(attribute)
			@associations ||= {}
			field, attr_type = attribute.split(":", 2)
			association_found = !!(attr_type =~ /#{supported_associations.join("|")}/)

			if association_found
				assoc = {}
				if !attr_type.index('[')
					assoc["type"] = attr_type
				else
					assoc["type"] = attr_type.gsub(/\[.*\]/, "")

					attr_type.scan(/\[(.*)\]/)[0][0].split(",").each do |option_pair| 
						option, value = option_pair.split(":")
						assoc[option] = value
					end
				end
				@associations[field] = assoc
			end
			association_found
		end

		# form_for should support namespaces and nested resources
		def form_for_args
			args = []
			args << ":#{namespace.underscore}" unless namespace.empty?
			args << "parent_object" unless associations.empty? ## TODO only do this when make_resourceful or simular library that supports nesting is available
			args << singular
		
			args.size == 1 ? args.first : "[#{args.join(", ")}]"
		end

		def plural
			plural_name.pluralize
		end
	
		def singular
			singular_name.singularize
		end

	  def path_for(action, options = {})
			options[:partial] ||= false
			object_instance = (options[:partial] ? "" : "@") + singular

	    case action
	    when :show
	      return "#{namespace_prefix + singular}_path(#{object_instance})"
	    when :edit
	      return "edit_#{namespace_prefix + singular}_path(#{object_instance})"
	    when :destroy
				return "#{namespace_prefix + singular}_path(#{object_instance})"
	    when :index  
				return "#{namespace_prefix + plural}_path"
			when :new
				return "new_#{namespace_prefix + singular}_path"
	    end  
	  end

		# Method that gives the template path
		# Should be overriden in plugins that provide other templates
		def template_path(filename = "")
			File.join($DM_TEMPLATE_PATH, filename)
		end

		# Returns the path to the template file 
		# and when a prefix is given also the name of the target filename 
		# (hence it thus returns a string or an array with two strings)
		def find_template_for(name, options = {})
			prefix = options[:prefix] ? options[:prefix] + "_" : ""
			type = options[:prefix]
			extension = ".erb" # I don't think this will and should change, but here as a variable any way to make it flexible
			path = template_path # the template_path can be overriden by subclasses
			
			# find files and raise errors when there is not exactly one matching file
			files = Dir.glob("#{path}#{prefix}#{name}*#{extension}")
			raise "Found more than one matching file in '#{path}' for '#{type}#{name}' template, candidates are: #{files.to_sentence}. Remove or rename one or more files." if files.size > 1
			raise "Found no matching file in '#{path}' for '#{type}#{name}' template. The file should have the following format '#{prefix}#{name}#{extension}'." if files.empty?

			# No we know there is only one file, and that file has the defined prefix and the define extension
			# We want to be able to load the templates from the rails root instead of dm_scaffold/dm_*/templates/ so we need to compensate this
			path_to_template = File.join(%w(.. .. .. .. .. ..) << files.first)

			# When there is a prefix, the target filename should be extracted from the found template in othercases not
			if options[:prefix]
				target_filename = File.basename(path_to_template, extension).slice(prefix.size..-1)
				[path_to_template, target_filename]
			else
				path_to_template
			end
		end

		def namespace
			@controller_class_nesting
		end

		def namespace_prefix(char = "_")
			namespace.empty? ? "" : "#{namespace.underscore}#{char}"
		end
	end
end
