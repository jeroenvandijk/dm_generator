require 'rails_generator'
require 'yaml'

module DM
	class ExtendedGeneratedAttribute < Rails::Generator::GeneratedAttribute
		# Create a singleton method that defines the types, loaded before other things happen
		# formats
		# 	:email: :string
		#	
		#	examples
		#		- email: name@name.com
			
				
		#
		# class << self
		# 	attr_accessor :format_mapping
		# 
		# 	def self.initialize_format_mapping(format_mapping = {})
		# 		@format_mapping = format_mapping
		# 	end
		# end
		def self.native_types
			@native_types ||= ActiveRecord::Base.connection.native_database_types
		end

		class << self
			attr_accessor :format_mapping, :file

			def init_format_mapping(file)
				@format_mapping = HashWithIndifferentAccess.new(YAML::load_file(file)).symbolize_keys!
				@file = file

				validate_mapping
			end
			
			def validate_mapping
				obligatory_fields = [:native_type,:examples, :display]
														
				format_mapping.each_key do |format|
					obligatory_fields.each do |field|
						raise "Validation of file '#{file}' failed: field '#{field}' is not defined for format '#{format}'" unless format_mapping[format][field]
					end
				end
			end

		end
		
		attr_accessor :format, :templates
		
		def initialize(*args)
			options = args.extract_options!
			
			name = args.first 
			format = args.second
			
			super(name, extract_type(format))
			@templates = options[:templates] || []
		end
		
		def default
			@default ||= mapping(:examples, :valid) || super
		end
	
		# display returns the value of the attribute in the way it is defined in the format mapping file
		# Expects the first argument to be the name of the template variable, e.g. @user or user
		# Second argument (optional) is the symbol for the template in which we want the attribute to display
		# Arbitrary parsing can be done in through the options hash, the {{key}} will be replaced with the value
		#   - 
		def display(*args)
			options = args.extract_options!
			object = args.first
			raise "The first argument should not be nil and should contain the name of object instance belonging to the attribute (attribute name: #{name})" unless object
			template = args.second || :default
			
			if native?
				"#{object}.#{name}"
			else
				# Find the display settings from the format_mapping hash
				display = mapping(:display, template)
				unless display
					puts mapping_missing_message_for(:display, template) + ", default is used"
					display = mapping(:display, :default)
					raise mapping_missing_message(:display) unless display
				end
				
				parse_display_template(display, options.reverse_merge(:object => object))
			end
		end

		private
		
			def mapping(type, template = :default)
				format_mapping[format] && format_mapping[format][type] && format_mapping[format][type][template]
			end

			def parse_display_template(display, options = {})
				display.gsub!("{{attribute_name}}", name)

				options.each_pair { |key, value| display.gsub!("{{#{key}}}", value ) }
			end
		
			def mapping_missing_message_for(type, template)
				"No :#{type} mapping for '#{format}' for :#{template} template in mapping file '#{file}'"
			end

			def native?
				native_types.has_key? format
			end

			delegate :format_mapping, :native_types, :file, :to => :parent
			
			def parent
				self.class
			end

			def extract_type(_format)
				# Set format and make sure it is a symbol, this way we can use it later on 
				@format = _format.to_sym

				type = _format if native?
				type ||= format_mapping[@format][:native_type].try
				raise "The native_type for format '#{format}' is not defined in #{file} and is also not a native rails type (#{native_types.to_sentence}) " unless type

				type
			end
	end
end