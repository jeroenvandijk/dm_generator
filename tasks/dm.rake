require "yaml" # For exporting and importing of the datamodel\
require 'find' # For finding namespaces
require File.dirname(__FILE__) + '/../lib/xmi_reader'
require File.dirname(__FILE__) + '/../lib/yaml_sort_extension'



namespace :dm do  
  
  desc "Runs script/generate with the given data model, runs migrations, loads fixtures and starts the server."
  task :install, :model_file do |t, args|
    
    succes = system "script/generate dm #{args.model_file} --template_dir=make_resourceful_ideal --force" 
    
    if succes
      
      require 'rails_generator/simple_logger'
      logger = Rails::Generator::SimpleLogger.new(STDOUT)
      
      logger.run("db:empty") do
         Rake::Task["db:drop"].invoke
         Rake::Task["db:create"].invoke
      end
      logger.run("db:migrate") { Rake::Task["db:migrate"].invoke }
      logger.run("db:fixtures:load") { Rake::Task["db:fixtures:load"].invoke }
        
      logger.run("script/server") { system "script/server 3000" }
    end

  end
  
  
  desc "routes"
  task :routes, :yaml_file do |t, args|
    
    data_model = read_yaml_file(args.yaml_file)
    make_routes(data_model)
  end
  
  def make_routes(data_model, options = {}) 
    root = options[:root] || "map"
    indent = options[:indent].to_s + "  "
    
    (data_model["models"] || {}).each_pair do |resource_name, properties|      

      resource_mapping = "#{indent}#{root}.resources :#{resource_name.pluralize}"
      
      if associations = properties["associations"]

        puts "#{resource_mapping} do |#{resource_name}|\n"
        associations.each do |association|
          nested_resource_name, type = association.to_a.flatten
          puts "  #{indent}#{resource_name}.resources :#{nested_resource_name.pluralize}" if type =~ /has_many|has_and_belongs_to_many/
        end
        puts end_block = "#{indent}end\n"
      else
        puts "#{resource_mapping}\n"
      end
      
    end
    
    (data_model["namespaces"] || {}).each_pair do |namespace_name, scoped_data_model|
      
      puts "#{indent}#{root}.namespace :#{namespace_name} do |#{namespace_name}|\n"

      make_routes(scoped_data_model, :root => namespace_name, :indent => indent)
      
      puts "#{indent}end\n"
      
    end
  end 

  desc "Imports a Yaml data model."
  task :import, :yaml_file do |t, args|
    puts read_yaml_file(args.yaml_file).to_yaml
  end

  desc "Exports a datamodel to Yaml by inspecting ActiveRecord models present in the models directory"
  task :export => :environment do

    puts(update_model.to_yaml)
  end
  
  desc "Updates all models defined in the Yaml file, does not rewrite options"
  task :update, :yaml_file do |t, args|
    data_model = read_yaml_file(args.yaml_file)
    
    puts update_model(data_model).to_yaml 
  end

  namespace :xmi do
    desc "Reads a xmi file and returns yaml"
    task :to_yaml, :xmi_file do |t, args|
      raise "No file given" unless args.xmi_file
      puts XmiReader.new(args.xmi_file).to_yaml
    end
  end
    
    
    
    
  def update_model(data_model = {})
    for_all_models do |model_class, model_name, namespaces|

      # Go to the right place in the hash
      data_model = namespaces.inject(data_model) do |base, namespace|
        data_model["namespaces"] ||= {}
        data_model["namespaces"][namespace] ||= {}

      # Add the model
        data_model["models"] ||= {}
        data_model["models"].reverse_merge!( model_name => { "associations" => extract_associations(model_class),
                                                            "attributes" => extract_attributes(model_class) } )

      end
    end
    data_model
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
      begin
        model_class = eval(model_name.classify) #TODO rescue when model does not exist

      rescue StandardError => boom
        print "Errors in filename: #{filename} \n" + boom
        next
      end
        

      if model_class.superclass == ActiveRecord::Base
          # Extract namespaces
          namespaces = find_namespaces_for(model_name) || []
          yield(model_class, model_name, namespaces)
      end
    end
  end
  
  # Find namespaces for model name, only gives the first found namespaces
  def find_namespaces_for(model_name, options = {})
    # namespaces are visible in controller directory
    options[:base_path] ||= "#{RAILS_ROOT}/app/controllers/"
    dir = options[:dir].to_s
    path = options[:base_path] + dir
    
    controller_files = Dir.glob("#{path}*.rb")

    if !controller_files.select {|f| f =~ /#{model_name.pluralize}_controller/}.empty?
      # raise controller_files.inspect + " \n\n path " + path
      return dir.split("/") # directory structure
    else


      Find.find(*Dir.glob(path + "*")) do |file|
        if path == file
          Find.prune       # Don't look any further into this directory.
          
        elsif FileTest.directory?(file)
          namespaces = find_namespaces_for(model_name, 
                                        options.merge(:dir => dir + File.basename(file) + "/") ) 

          return namespaces if namespaces #we found something
        end

        next #directory
      end
    end
    
    # Controller not found so assume we should add no namespace
    return nil
  end
  
  def extract_associations(klass)
    associations = []
    klass.reflect_on_all_associations.each do |assoc|
      association = {assoc.name.to_s => assoc.macro.to_s}
      
      association["options"] = assoc.options unless assoc.options.empty?
      
      associations << association
    end
    associations
  end
  
  # Attributes are extracted by inspecting the class. 
  # It uses the reasonable convention that an corresponding database table exist for the model.
  # Attributes are extracted by inspecting the class. 
  # It uses the reasonable convention that an corresponding database table exist for the model.
  def extract_attributes(klass)
    model_attribute_match = klass.inspect.scan(/\((.*)\)/).flatten[0]

    if model_attribute_match
      raw_model_attributes =  model_attribute_match.split(", ")
      
      raw_model_attributes.inject([]) do |attributes, raw_attribute_pair| 
        
        # Add attribute if it not an a rails id or a rails timestamp
        attributes << YAML::load(raw_attribute_pair) unless raw_attribute_pair =~ /[\w+_]*id|created_at|updated_at/
      
        attributes
      end
    else
      []
    end
  end
end