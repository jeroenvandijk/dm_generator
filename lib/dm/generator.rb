require 'rails_generator'
require File.dirname(__FILE__) + '/../yaml_sort_extension'

module DM
	class ExtendedNamedBase < Rails::Generator::NamedBase
     
    attr_reader :models,                    # attributes accessed from the main generator
                :models_hash,
                :model_filename,
                :model_file_content,
                :indention_style            # attributes used accessed from model

	  def initialize(runtime_args, runtime_options = {})
      initialize_before_super_call

      super

      filename = @name
      @indention_style = "  "

      # The Attribute class should know of our own defined formats
			ExtendedGeneratedAttribute.initialize_formats(template_path("formats.yml", template_dir))

      Model::Base.generator = self  
      
      reader = Reader.new(filename, options)      
      @models = reader.models
      @models_hash = reader.models_hash

      # Set yaml properties so we can use it in the manifest for copying the file
      @model_filename     = File.basename(filename, '.*') + '.yml'
      @model_file_content = reader.original_hash.to_yaml

    end
    
    def initialize_before_super_call
      @template_types = { :views            => { :abbreviation => :v },
                          :models           => { :abbreviation => :m },
                          :controllers      => { :abbreviation => :c },
                          :helpers          => { :abbreviation => :h, :exclude_by_default => true },
                          :fixtures         => { :abbreviation => :f },
                          :routes           => { :abbreviation => :r },
                          :migrations       => { :abbreviation => :d },
                          :controller_tests => { :abbreviation => :i },
                          :model_tests      => { :abbreviation => :u },
                          :mailers          => { :abbreviation => :e, :exclude_by_default => true }, # Should be explicitly stated in the model definition
                          :observers        => { :abbreviation => :o, :exclude_by_default => true },
                          :language_files   => { :abbreviation => :l } }
      @files_to_create = @template_types.keys
      
    end

	  protected

    attr_reader :template_types

    # A template should be generated when the command given to the generator allows this (only and except) AND
    # the template should be include by default or the value given should be true (for instance when that is defined in the model file)
    def template_should_be_generated?(template, options = {})
      template_type = template.to_s.pluralize.to_sym
      
      files_to_include = options[:files_to_include] || []
      files_to_exclude = options[:files_to_exclude] || []
      
      if files_to_exclude.map(&:pluralize).include? template_type.to_s                         # File is defined to be excluded in the model template, return false
        return false
        
      elsif @files_to_create.include?(template_type)
                      
        if template_types[template_type][:exclude_by_default]                                   # File is exclude by default so it depends on the model definition?, return value 
          return files_to_include.map(&:pluralize).include?(template_type.to_s)
        else
          return true
        end
      else
        # The template wasn't requested so
        return false
      end
    end

    def set_files_to_create(abbreviations_string, to_include)
      abbreviations = abbreviations_string.split('').map{|x| x.to_sym }
      
      @files_to_create = template_types.reject do |template_name, properties| 
                           in_abreviations  = abbreviations.include?(properties[:abbreviation])
                           to_include ? !in_abreviations  :  in_abreviations
                         end.keys
    end

    def add_options!(opt)
      # raise @template_types.inspect
      abbreviations = @template_types.to_a.map{|x| "#{x.second[:abbreviation]} (#{x.first})" }.join("\n" + "\t" * 9 + "  ")

      opt.separator ''
      opt.separator 'Options:'
			opt.on("--template_dir=", String,
						 "Search for templates in the given directory first, then default") do |v|
								options[:template_dir] = v
							end

			opt.on("--test_type=", String,
						 "Test type is spec (RSpec) by default") do |v|
								options[:test_type] = v
							end

      opt.on("--only=", String,
             "Only create these templates types: " + abbreviations) { |abbreviation_args| set_files_to_create(abbreviation_args, true) }

      opt.on("--except=", String,
             "Don't generate these template types: " + abbreviations) { |abbreviation_args| set_files_to_create(abbreviation_args, false) }
			

    end


		def banner
			generator_name = self.class.to_s.underscore.gsub("_generator", "")
			usages = []
			usages << "Usage: #{$0} #{generator_name} file_with_model_definition.[yml|xmi] [options]"
			usages.join("\n")
	  end

		def template_dir
			options[:template_dir]
		end
		
		def test_suffix
		  options[:test_suffix] || "spec"
	  end
		  

    def template_path(filename = "", dir = nil)
      File.join($DM_TEMPLATE_PATH, dir || "default", filename)
    end
		# Returns the path to the template file 
		# and when a prefix is given also the name of the target filename 
		# (hence it thus returns a string or an array with two strings)
		def find_template_for(name, options = {})
			extension = ".erb" # I don't think this will and should change, but here as a variable any way to make it flexible
			path = template_path("", template_dir) # the template_path can be overriden by subclasses

      @template_for ||= {}
      unless @template_for[name]
  			# find files and raise errors when there is not exactly one matching file
  			files = Dir.glob("#{path}#{name}*#{extension}")

  			# If there are no files found try it again for the default directory
  			if files.empty? && template_dir
  				files = Dir.glob("#{template_path}#{name}*#{extension}")
  			end
			
  			if files.size > 1
          files.sort!{|a,b| a.length <=> b.length }
        
  			  puts "Found more than one matching file in '#{path}' for '#{name}' template, candidates are: #{files.to_sentence}. The match with the shortes length is chosen: '#{files.first}'."
  			end

  			raise "Found no matching file in '#{path}' for '#{name}' template. The file should have the following format '#{name}#{extension}'." if files.empty?

  			# No we know there is only one file, and that file has the defined prefix and the define extension
  			# We want to be able to load the templates from the rails root instead of dm_scaffold/dm_*/templates/ so we need to compensate this
  			@template_for[name] = path_to_template = File.join(%w(.. .. .. .. .. ..) << files.first)
			 end
			 @template_for[name]
		end
	end
end
