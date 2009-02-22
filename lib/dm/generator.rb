require 'rails_generator'
require File.dirname(__FILE__) + '/../yaml_sort_extension'

module DM
	class ExtendedNamedBase < Rails::Generator::NamedBase
    attr_reader :models, :yaml_filename, :yaml_content

	  def initialize(runtime_args, runtime_options = {})
			super
      filename = @name

			DM::ExtendedGeneratedAttribute.init_formats(template_path("formats.yml", template_dir))

      DM::Model::Base.file_instructions = options.reject {|key, _| ![:files_to_ignore, :files_to_include].include?(key) }
      DM::Model::Base.add_options(:model_file => filename, :indention_style => "  " )

      reader = DM::Reader.new(filename, options)      
      @models = reader.models

      # Set yaml properties so we can use it in the manifest for copying the file
      @yaml_filename = File.basename(filename, '.*') + '.yml'
      @yaml_content = reader.original_hash.to_yaml
      
		end
			
	  protected

    def add_options!(opt)
      abbreviations = DM::Model::Base.template_settings.to_a.map{|x| "#{x.first} (#{x.second[:abbreviation]})" }.join(", ")

      opt.separator ''
      opt.separator 'Options:'
      opt.on("--only=", String,
             "Only create these templates types: " + abbreviations) do |v|
               options[:files_to_include] = v.split('').map{|x| x.to_sym }
             end
      opt.on("--except=", String,
             "Don't generate these template types: " + abbreviations) do |v| 
               options[:files_to_ignore] = v.split('').map{|x| x.to_sym }
             end
			
			opt.on("--template_dir=", String,
						 "Search for templates in the given directory first, then default") do |v|
								options[:template_dir] = v
							end
			opt.on("--test_type=", String,
						 "Test type is spec (RSpec) by default") do |v|
								options[:test_type] = v
							end
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
