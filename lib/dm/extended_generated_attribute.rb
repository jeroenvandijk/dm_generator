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
				top_level_symbols = [:examples, :presentations, :formats]

				# raise format_mapping.inspect
				unless top_level_symbols.inject(true) {|included, sym| included && format_mapping.has_key?(sym)} 
					raise "The format mapping hash in '#{file}' is missing the top level keys: #{(top_level_symbols - format_mapping.keys).to_sentence}."
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
			@default ||= format_mapping[:examples][format] || super
		end
	
		# Presentation gives us a method to automatically present the attribute in the way we want it
		def presentation(*args)
			# extract arguments
			options = args.extract_options!
			object = args.first
			raise "The first argument should not be nil and should contain the name of object instance belonging to the attribute (attribute name: #{name})" unless object
			template = args.second || :default
			
			if native?
				"#{object}.#{name}"
			else
				# Find the presentation settings from the format_mapping hash
				raise "No presentation mapping for '#{template}' template on object '#{object}'" unless format_mapping[:presentations][template]
				
				presentation = format_mapping[:presentations][template][format]
				unless presentation
					puts "No presentation mapping for '#{format}' format on object '#{object}' for template '#{template}', default is used." 
					presentation = format_mapping[:presentations][:default][format]
					raise "No presentation mapping for for '#{format}' format on object for :default template'#{object}'" unless presentation
				end

				# Replace template variables with their values
				presentation.gsub!("{{attribute}}", name)
				presentation.gsub!("{{object}}", object)
				presentation.gsub!("{{_self}}", "#{object}.#{name}")

				options.each_pair { |key, value| presentation.gsub!("{{#{key}}}", value ) }
				presentation
			end
		end
		
		private

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

				# Continue extracting the type using the member format 
				# See if we can find a mapping of the format
				type = format_mapping[:formats][format]
				raise "The mapping for the format '#{format}: #{type}' is not a native database type" unless type || native?

				# If we haven't found a mapping use the native type if it is one
				unless type
					if native?
						type = _format
					else
						raise "The mapping for the format '#{format}' is not defined for #{self.class}."
					end
				end

				type
			end
	end
end