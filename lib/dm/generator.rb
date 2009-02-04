require 'rails_generator'

module DM
	class ExtendedNamedBase < Rails::Generator::NamedBase
    attr_reader :scaffold_views,
                :models
                
    attr_accessor :current_model
    
	  def initialize(runtime_args, runtime_options = {})
			super

      filename = @name

      options = {} 
      options[:supported_associations] = %w(belongs_to has_many has_and_belongs_to_many has_one)
      options[:supported_association_options] = %w(through dependent)
      options[:parent_associations] = %w(belongs_to has_and_belongs_to_many)

      model_hash = YAML::load_file(filename)
      @models = DM::Reader.new(model_hash, options).models
      
      # Set other variables
      @scaffold_views = %w(index show new edit _form _partial)
		end
			
	  protected

    def abbreviations_mapping
        @abbreviations ||= {
          :views => :v,
          :models => :m,
          :controllers => :c,
          :helpers => :h,
          :fixtures => :f,
          :routes => :r,
          :migrations => :d,
          :integration_tests => :i,
          :unit_tests => :u
        }
    end
    
    def is_requested?(key)
      !(options[:files_to_ignore] && options[:files_to_ignore].include?(abbreviations_mapping[key]))
    end

    def add_options!(opt)
      abbreviations = "models(m) views(v) controllers(c) helpers(h)" + 
                      "fixtures(f) routes(r) database migrations (d) integration tests(i)" + 
                      "units tests(u)"
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--only=", String,
             "Only create these templates types: " + abbreviations) do |v|
               options[:files_to_ignore] = abbreviations_mapping.values - v.split('').map{|x| x.to_sym }
             end
      opt.on("--except=", String,
             "Don't generate these template types: " + abbreviations) do |v| 
               options[:files_to_ignore] = v
             end
    end


		def banner
			generator_name = self.class.to_s.underscore.gsub("_generator", "")
			usages = []
			usages << "Usage: #{$0} #{generator_name} file_with_model_definition.yml"
			usages.join("\n")
	  end

    def path_for(action, options = {})
			object_instance = (options[:partial] ? "" : "@") + current_model.model_name
      resource_name = (current_model.namespaces + [current_model.model_name]).join("_").downcase

	    case action.to_sym
	    when :show
	      return "#{resource_name}_path(#{object_instance})"
	    when :edit
	      return "edit_#{resource_name}_path(#{object_instance})"
	    when :destroy
				return "#{resource_name}_path(#{object_instance})"
	    when :index  
				return "#{resource_name.pluralize}_path"
			when :new
				return "new_#{resource_name}_path"
	    end  
	  end

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
	end
end
