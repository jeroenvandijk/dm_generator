require 'rails_generator'
require 'rails_generator/commands'

module DM #:nodoc:
  module Generator #:nodoc:
    module Commands #:nodoc:
      module Create
				def routes_nested_resources(raw_resource, parents, indention)
					self.indention_string = indention

					log_route(raw_resource, parents)
					edit_file "config/routes.rb" do |routes|
						add_route(routes, raw_resource, parents)
					end
				end
      end

      module Destroy
        def routes_nested_resources(raw_resource, parents, indention)
					self.indention_string = indention
					log_route(raw_resource, parents)

					edit_file "config/routes.rb" do |routes|
						delete_route(routes, raw_resource, parents)
					end
				end
			end
			
      module List
        def routes_nested_resources(raw_resource, parents, indention)
					self.indention_string = indention

					log_route(raw_resource, parents)
        end
      end

			module Utilities
				attr_accessor :indention_string
				
				def edit_file(relative_destination)
			    path = destination_path(relative_destination)
			    content = yield(File.read(path))
			    File.open(path, 'wb') { |file| file.write(content) }
			  end

				def log_route(raw_resource, parents)
					namespace, resource = parse_resource(raw_resource)
					# for the console we need a different indention
					self.indention_string, tmp_indention_string = "\t\t", indention_string
					
					if !namespace
						if parents.empty? 
							 logger.route  "normal route: " + normal_route(resource).lstrip
						else
							parents.each { |parent| logger.route "nested route: " + nested_route(parent, resource).lstrip }
						end
					else
						if parents.empty?
							logger.route "namespace route :" + namespace_route(namespace, resource).lstrip
						else
							parents.each {|parent| logger.route "namespace nested route" + namespace_nested_route(namespace, parent, resource).lstrip }
						end
					end
					
					# undo temp change of indention string
					self.indention_string = tmp_indention_string
				end
				
				def add_route(routes, raw_resource, parents = [])
					namespace, resource = parse_resource(raw_resource)
					
					if namespace
						if parents.empty?
							add_namespace_route(routes, namespace, resource)
						else
							parents.inject(routes){|new_routes, parent| add_namespaced_nested_route(new_routes, namespace, parent.pluralize, resource) }
						end
					else
						if parents.empty?
							add_normal_route(routes, resource)
						else
							parents.inject(routes){|new_routes, parent| add_nested_route(new_routes, parent.pluralize, resource) }
						end
					end
				end
				
				def delete_route(routes, raw_resource, parents = [])
					namespace, resource = parse_resource(raw_resource)

					if namespace
						if parents.empty?
							# add_namespace_route(routes, namespace, resource)
						else
							# parents.each {|parent| add_namespaced_nested_route(routes, namespace, parent, resource) }
						end
					else
						if parents.empty?
							# add_normal_route(routes, resource)
						else
							# parents.each {|parent| add_nested_route(routes, parent, resource) }
						end
					end
					
					routes # TODO remove and implement
				end
				
				def delete_normal_route
					
				end
				
				def delete_namespace_route
					
				end
				
				def delete_nested_route
					
				end

				def add_namespaced_nested_route(routes, namespace, parent, resource)
					if namespaced_nested_resource_exist?(routes, namespace, parent, resource)
						routes 
					elsif namespaced_resource_with_block_exist?(routes, namespace, parent)
						routes.gsub(/#{namespaced_resource_with_block_regx(namespace, parent)}/) do |match|
							match + normal_route(resource, :base => parent.singularize, :indent => 3) + "\n"
						end
					elsif namespaced_resource_exist?(routes, namespace, parent)	
						routes.gsub(/#{namespace_resource_regx(namespace, parent)}/) do |match|
							match + do_route_block(parent, resource, :indent => 3)#+ " jeroen jeroen jeroen jeroen jeroen jeroen jeroen"
						end
					elsif namespace_exist?(routes, namespace)
						routes.gsub(/#{namespace_regx(namespace)}/) do |match|
							match + nested_route(parent, resource, :base => namespace, :indent => 2) + end_of_block(2) + "\n"
						end
					else
						routes.gsub(/#{sentinel_regx}/m) do |match|
							match + "\n" + namespace_nested_route(namespace, parent, resource) + end_of_block(2) + end_of_block
						end
					end
				end
				
				def add_nested_route(routes, parent, resource)
					if nested_resource_exist?(routes, parent, resource)
						routes
					elsif resource_with_block_exist?(routes, parent)
						routes.gsub(/#{resource_with_block_regx(parent)}/m) do |match|
							match + normal_route(resource, :base => parent.singularize, :indent => 2) + "\n" 
						end
					elsif resource_exist?(routes, parent)
						routes.gsub(/#{resource_regx(resource)}/m) do |match|
							match + do_route_block(parent, resource) 
						end
					else
						routes.gsub(/#{sentinel_regx}/m) do |match|
							match + "\n" + nested_route(parent, resource) + end_of_block
						end
					end
				end

				def add_namespace_route(routes, namespace, resource)
					if namespaced_resource_exist?(routes, namespace, resource)
						routes
					elsif namespace_exist?(routes, namespace)
						routes.gsub(/#{namespace_regx(namespace)}/m) do |match|
							match + normal_route(resource, :base => namespace, :indent => 2) + "\n"
						end
					else
						routes.gsub(/#{sentinel_regx}/m) do |match| 
							match + "\n" + namespace_route(namespace, resource, :indent => 1) + end_of_block
						end
					end
				end
				
				def add_normal_route(routes, resource)
					if routes.scan(/#{resource_regx(resource)}/m).empty?
						routes.gsub(/#{sentinel_regx}/m) do |match|
							"#{match}\n\tmap.resources :#{resource}"
						end
					else # requested route already exist
						routes
					end
				end
				
				def namespace_route(namespace, resource = nil, options = {})
					base = options[:base] || "map"
					indent_level = options[:indent] || 1
					indention = indent(indent_level)
					
					"#{indention}#{base}.namespace :#{namespace} do |#{namespace}|\n" +
					(block_given? ? yield : normal_route(resource, :base => namespace, :indent => indent_level + 1))
				end
				
				def nested_route(parent_resource, resources, options = {})
					indent_level = options[:indent] || 1
					base = options[:base] || "map"

					normal_route(parent_resource, :base => base, :indent => indent_level) + 
					do_route_block(parent_resource, resources, :indent => indent_level + 1) 
				end
				
				def do_route_block(base, resources, options = {})
					indent_level = options[:indent] || 2
					singular_base = base.singularize
					" do |#{singular_base}|\n" + normal_route(resources, :base => singular_base, :indent => indent_level)
				end

				def end_of_block(indent_level = 1)
					"\n#{indent(indent_level)}end"
				end
				
				def normal_route(resource, options = {})
					base = options[:base] || "map"
					indention = indent(options[:indent])
					"#{indention}#{base.singularize}.resources :#{resource.pluralize}"
				end
				
				def namespace_nested_route(namespace, parent_resource, resource)
					namespace_route(namespace) { nested_route parent_resource, resource, :base => namespace, :indent => 2 }
				end

				def namespace_exist?(routes, namespace)
					!routes.scan(/#{namespace_regx(namespace)}/m).empty?
				end
				
				def namespaced_resource_exist?(routes, namespace, resource)
					!routes.scan(/#{namespace_resource_regx(namespace, resource)}/m).empty?
				end
				
				def resource_with_block_exist?(routes, resource)
					!routes.scan(/#{resource_with_block_regx(resource)}/m).empty?
				end
				
				def nested_resource_exist?(routes, parent, resource)
					!routes.scan(/#{nested_resource_regx(parent, resource)}/m).empty?
				end
				
				def namespaced_resource_with_block_exist?(routes, namespace, parent)
					!routes.scan(/#{namespaced_resource_with_block_regx(namespace, parent)}/m).empty?
				end
				
				def namespaced_nested_resource_exist?(routes, namespace, parent, resource)
					!routes.scan(/#{namespaced_nested_resource_regx(namespace, parent, resource)}/m).empty?
				end

				def resource_exist?(routes, resource)
					!routes.scan(/#{resource_regx(resource)}/m).empty?
				end
					
					
				# Matches:
				# map.namespace :namespace do |namespace|
				#  namespace.resources :parent do |parent|
				#    parent.resource :child
				def namespaced_nested_resource_regx(namespace, parent, resource)
					namespaced_resource_with_block_regx(namespace, parent) + 
					'.*' + resource_regx(resource, :base => parent.singularize)
				end

				# Mathches:
				# map.namespace :namespace do |namespace|
				#  namespace.resource :parent do |parent|
				def namespaced_resource_with_block_regx(namespace, resource)
					namespace_resource_regx(namespace, resource) + begin_of_block_regx(resource.singularize)
				end

				# Matches
				# map.namespace :namespace do |namespace|
				#   namespace.resources :resource
				def namespace_resource_regx(namespace, resource)
					namespace_regx(namespace) + /.*/.source + resource_regx(resource, :base => namespace)
				end


				# Matches
				# map.namespace :namespace do |namespace|
				#
				def namespace_regx(namespace)
					/map\.namespace\s+:#{namespace}/.source + begin_of_block_regx(namespace)
				end
				
				# Matches
				# base.resources :parent do |parent|
				#    parent.resources :child
				#
				def nested_resource_regx(parent, resource, options = {})
					base = options[:base] || "map"
					resource_with_block_regx(parent, :base => base) +
					/.*#{resource_regx(resource, :base => parent.singularize)}/m.source
				end

				# Matches
				# base.resources :parent do |parent|
				# 
				def resource_with_block_regx(parent, options = {})
					base = options[:base] || "map"
					resource_regx(parent, :base => base) + begin_of_block_regx(parent.singularize)
				end

				# Matches 
				#  do |name| 
				#
				def begin_of_block_regx(argument_name)
					/\s+do\s+\|#{argument_name}\|\s*\n/.source
				end
				
				# Matches:
				# map.resources :resource
				def resource_regx(resource, options = {})
					base = options[:base] || "map"
					/#{base}.resources\s+:#{resource}/.source
				end
				
				# Matches start of routing file
				def sentinel_regx
					/(#{Regexp.escape('ActionController::Routing::Routes.draw do |map|')})/mi.source
				end
				
				def parse_resource(raw_resource)
					namespace, resource = raw_resource.split('/')
					if resource
						resource = resource.pluralize
					else
						resource, namespace = namespace.pluralize, nil
					end
					[namespace, resource]
				end
				
				def indent(level = nil)
					# Set a default and make sure indent can be called with zero argument or with a nil argument
					level = 1 unless level
					# Use the indention_string which is attribute of the module
					indention_string * level
				end
			end
		end
  end
end

# include Utility module in all Command modules
%w(Create Destroy List).each do |action|
	eval("DM::Generator::Commands::#{action}").send :include, DM::Generator::Commands::Utilities
end

# Extend rails commands
Rails::Generator::Commands::Create.send   :include,  DM::Generator::Commands::Create
Rails::Generator::Commands::Destroy.send  :include,  DM::Generator::Commands::Destroy
Rails::Generator::Commands::List.send     :include,  DM::Generator::Commands::List
# Rails::Generator::Commands::Update.send   :include,  DM::Generator::Commands::Update
