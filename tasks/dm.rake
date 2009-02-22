require "yaml" # For exporting and importing of the datamodel\
require 'find' # For finding namespaces
require File.dirname(__FILE__) + '/../lib/xmi_reader'
require File.dirname(__FILE__) + '/../lib/yaml_sort_extension'

namespace :dm do  
  desc "Creates the database, runs script/generate with the given data model, runs migrations, loads fixtures."
  task :install, :model_file do |t, args|

    require 'rails_generator/simple_logger'
    logger = Rails::Generator::SimpleLogger.new(STDOUT)

    logger.run("db:create") { Rake::Task["db:create"].invoke }
    
    system "script/generate dm #{args.model_file} --force"     

    logger.run("dm:menu") { Rake::Task["dm:menu"].invoke(args.model_file) }
    logger.run("db:migrate") { Rake::Task["db:migrate"].invoke }
    logger.run("db:fixtures:load") { Rake::Task["db:fixtures:load"].invoke }

  end
  
  
  desc "Prints the routes that will be created if a datamodel is generated"
  task :routes, :model_file do |t, args|
    
    data_model = read_model_file(args.model_file)
    make_routes(data_model)
  end

  desc "Creates a html menu given the data model"
  task :menu, :model_file do |t, args|

    data_model = read_model_file(args.model_file)  
    menu = build_menu(data_model)

    indent = "  "
    menu_string = ["<ul>"]
    menu.each do |item|
      prefixed_item = item.second + item.first
      item_name = item.first
      menu_string << %@#{indent}<li><%= link_to "#{item_name}", #{prefixed_item.pluralize}_path %>@
      if item.size == 2
        menu_string.last <<  "</li>"
      else
        menu_string << "#{indent * 2}<ul>"
        item.last.each do |sub_item|
          menu_string << %@#{indent * 3}<% #{item_name.classify}.all.each do |#{item_name}| %>@
          menu_string << %@#{indent * 4}<li><%= link_to "#{sub_item} from #{item_name} " + #{item_name}.id.to_s, #{prefixed_item}_#{sub_item.pluralize}_path(#{item_name}) %></li>@
          menu_string << %@#{indent * 3}<% end %>@
        end
        menu_string << "#{indent * 2}</ul>"
        menu_string << "#{indent}</li>"
      end
    end
    menu_string << "</ul>"
    path = File.join(RAILS_ROOT, "app/views/layouts/_menu.html.erb")
    
    File.open(path, 'wb') {|f| f.write("<div class='menu'>\n" + menu_string.join("\n") + "\n</div>") }    
  end

  def build_menu(data_model, prefix = "")
    menu = []
    prefix = ""
    (data_model["models"] || {}).each_pair do |resource_name, properties|      
      item = [resource_name, prefix]

      if associations = properties["associations"]
        sub_items = []
        associations.each do |association|
          nested_resource_name, type = association.to_a.flatten
          sub_items << nested_resource_name if type =~ /has_many|has_and_belongs_to_many/
        end
      end
      item << sub_items if sub_items.any?
      menu << item  
    end
    
    (data_model["namespaces"] || {}).each_pair do |namespace_name, scoped_data_model|
      menu += build_menu(scoped_data_model, namespace_name + "_")
    end
    
    menu          
  end

  desc "Imports a Yaml data model."
  task :import, :model_file do |t, args|
    puts read_model_file(args.model_file).to_yaml
  end

  desc "Exports a datamodel to Yaml by inspecting ActiveRecord models present in the models directory"
  task :export => :environment do

    puts(update_model.to_yaml)
  end
  
  desc "Updates all models defined in the Yaml file, does not rewrite options"
  task :update, :model_file do |t, args|
    data_model = read_model_file(args.model_file)
    
    puts update_model(data_model).to_yaml 
  end

  namespace :xmi do
    desc "Reads a xmi file and returns yaml"
    task :to_yaml, :xmi_file do |t, args|
      raise "No file given" unless args.xmi_file
      puts XmiReader.new(args.xmi_file).to_yaml
    end
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

  namespace :destroy do
    
    desc "Destroys the whole application"
    task :with_force do
      Rake::Task["db:drop"].invoke
      
      dirs = %w(app/models app/controllers/ app/helpers/ app/views/ db/migrate/ test spec)
      ignore_pattern = /application_controller.rb|application.rb|application_helper.rb|spec_helper.rb|layouts/
      files_and_directories = dirs.map{ |dir| Dir.glob(dir + "*") }.flatten.reject{|f| File.basename(f) =~ ignore_pattern }
      # files_and_directories << "config/routes.rb"
      system "rm -rf " + files_and_directories.join(" ")
      # File.open("config/routes.rb", 'w') {|f| f.write("ActionController::Routing::Routes.draw do |map|\n\n end") }
      
    end

  end
  
  def for_data_model(file)
    data_model = read_model_file(file)
    data_model["models"].each_pair do |model, properties|
      yield(model, properties)
    end
  end
  
  def read_model_file(file)
    raise "No file given" unless file
    raise "File '#{file}' does not exist" unless File.exist?(file)
        
    extension = file.split('.').last

    raise "Models file should be of the format yml or xmi. The given file '#{file}' has an '#{extension}' extension." unless extension =~ /yml|xmi/

    begin
      extension == "xmi" ? XmiReader.new(file).to_h : YAML::load_file(file) 

    rescue StandardError => e
      raise "Models file '#{file}' could not be loaded: #{e}"
    end

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