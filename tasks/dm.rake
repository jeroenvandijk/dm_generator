require "yaml" # For exporting and importing of the datamodel

namespace :dm do
	desc "Imports a Yaml data model."
	task :import, :yaml_file do |t, args|
		puts read_yaml_file(args.yaml_file).to_yaml
	end

	desc "Exports a datamodel to Yaml by inspecting ActiveRecord models present in the models directory"
	task :export => :environment do
				
		data_model = {}
		for_all_models do |model_class, model_name|
			data_model[model_name] = {	"associations" => extract_associations(model_class),
																	"attributes" => extract_attributes(model_class) }
		end
		puts({"models" => data_model}.to_yaml)
	end

	desc "Destroy current data model (including all generated migrations, views and controllers)"
	task :destroy do
		empty_database
 
		# Destroy all existing models
		for_all_models { |_, model| destroy model }
	end

	namespace :destroy do
		desc "Destroys the data_model that is given in the yaml file."
		task :from_file, :yaml_file do |t, args|
			destroy_entities args.yaml_file, "scaffold"
			empty_database
		end
		
		desc "Destroys the whole application"
		task :with_force do
			empty_database
			dirs = %w(app/models app/controllers/ app/helpers/ app/views/ db/migrate/ test spec)
			ignore_pattern = /application_controller.rb|application.rb|application_helper.rb|layouts/
			files_and_directories = dirs.map{ |dir| Dir.glob(dir + "*") }.flatten.reject{|f| File.basename(f) =~ ignore_pattern }
			files_and_directories << "config/routes.rb"
 			system "rm -rf " + files_and_directories.join(" ")
			File.open("config/routes.rb", 'w') {|f| f.write("ActionController::Routing::Routes.draw do |map|\n\n end") }
			

		end
		
		# namespace :from_file do
		# 	desc "Destroy models"
		# 	task :models, :yaml_file do |t, args|
		# 	TODO	
		# 		empty
		# end
	end

	desc "Runs scaffolds to create the datamodel as in the given file"
	task :generate, :yaml_file do |t, args|
		generate_entities args.yaml_file, "scaffold"
		reset_database
		Rake::Task["db:fixtures:load"].invoke
	end
	
	namespace(:generate) do
		desc "Generates all models defined in the datamodel"
		task :models, :yaml_file do |t, args|
			generate_entities args.yaml_file, "model"
			reset_database
		end
	
		desc "Generates all models defined in the datamodel"
		task :views, :yaml_file do |t, args|
				generate_entities args.yaml_file, "views"
		end
	
		desc "Generates all routes according to the relations in the datamodel"
		task :routes, :yaml_file do |t, args|
			generate_entities args.yaml_file, "routes"
		end
	
		desc "Generates all models defined in the datamodel"
		task :controllers, :yaml_file do |t, args|
				generate_entities args.yaml_file, "controllers"
		end
	end

	def destroy_entities(file, entity)
		for_data_model(file) do |model, properties|
			destroy generate_arguments(model, properties), entity
		end
	end

	def generate_entities(file, entity )
		for_data_model(file) do |model, properties|
			generate generate_arguments(model, properties), entity
		end
	end

	
	def generate_arguments(model, properties)
		attributes_to_ignore = %w(id updated_at created_at) # Are already there so we don't need to add them

		attributes = []
		properties["attributes"].reject{|attr,_| attributes_to_ignore.include?(attr)}.
			each_pair do |field, type| 
				attributes << "#{field}:#{type}" 
			end

		associations = []
		properties["associations"].each_pair do |name, prop| 
			options = []
			prop.keys.each do |option|
				options << "#{option}:#{prop[option]}" if prop[option] && option != "type"
			end
			associations << "#{name}:#{prop["type"]}[#{options.join(",")}]" 
		end
		
		namespace = properties["namespace"] + '/' if properties["namespace"] 
		namespace ||= ""
		"#{namespace}#{model} #{(attributes + associations).join(" ")}"
	end
		
	def reset_database
		empty_database
		Rake::Task["db:migrate"].invoke
	end	

	def drop_database
		Rake::Task["db:reset"].invoke
	end
	
	def empty_database
		drop_database
		Rake::Task["db:create"].invoke
	end

	def generator
		"dm"
	end

	def destroy(args, action = "scaffold")
		script "destroy", args, action
	end
	
	def generate(args, action = "scaffold")
		script "generate", args, action
	end
	
	def script(type, args, action)
		system "script/#{type} #{generator}_#{action} #{args} --backtrace" 
	end
	
	def for_data_model(file)
		data_model = read_yaml_file(file)
		data_model["models"].each_pair do |model, properties|
			yield(model, properties)
		end
	end
	
	def read_yaml_file(file)
		raise "No file given" unless file
		raise "File '#{file}' does not exist" unless File.exist?(file)
		
		YAML::load_file(file)
	end
	
	def for_all_models 
		model_files = Dir.glob("#{RAILS_ROOT}/app/models/*.rb")
		model_files.each do |filename|
			model_name = File.basename(filename, ".rb")
			model_class = eval(model_name.classify) #TODO rescue when model does not exist
			if model_class.superclass == ActiveRecord::Base
					yield(model_class, model_name)
			end
		end
	end
	
	def extract_associations(klass)
		associations = {}
		klass.reflect_on_all_associations.each do |assoc|
			association = {"type" => assoc.macro.to_s}
			unless assoc.options.empty?
				association["through"] = assoc.options[:through].to_s if assoc.options[:through]
				association["dependent"] = assoc.options[:dependent].to_s if assoc.options[:dependent]
			end
			associations[assoc.name.to_s] = association
		end
		associations
	end
	
	# Attributes are extracted by inspecting the class. 
	# It uses the reasonable convention that an corresponding database table exist for the model.
	def extract_attributes(klass)
		model_attribute_match = klass.inspect.scan(/\((.*)\)/).flatten[0]
		raw_model_attributes =  model_attribute_match.gsub(", ", "\n")
		YAML::load(raw_model_attributes)
	end
end