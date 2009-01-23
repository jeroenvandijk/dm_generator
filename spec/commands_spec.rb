require File.dirname(__FILE__) + '/spec_helper'

class Dummy
	include DM::Generator::Commands::Utilities
end

describe Dummy do
		before(:each) do
			@klass = Dummy.new
			@klass.indention_string = "\t"
		end
	
	describe "'add_normal_route'" do
		it "should add a route when not present" do
			routes = routes_file("apples")
			@klass.add_route(routes, "bananas").should == routes_file(%w(bananas apples))		
		end
	
		it "should not add when present" do
			routes = routes_file(%w(apples bananas))
			@klass.add_route(routes, "apples").should == routes			
		end
	end
	
	describe "'add_namespace_route'" do
		it "should add a namespace when this does not exist" do
			@klass.add_namespace_route(empty_routes_file, "admin", "bananas").should == namedspace_routes_file("admin", "bananas")
		end
		
		it "should add a route under the namespace when it does not exist under the namespace" do
			routes = namedspace_routes_file("admin", "apples")
			@klass.add_namespace_route(routes, "admin", "bananas").should == namedspace_routes_file("admin", %w(bananas apples))
		end
		
		it "should not add a route when the route already exist under the namespace" do
			routes = namedspace_routes_file("admin", %w(apple bananas))
			@klass.add_namespace_route(routes, "admin", "apple").should == routes
		end
	end

	describe "'add_nested_route'" do
		it "should add a parent and a nested routes when the parent does not exist" do 
			@klass.add_nested_route(empty_routes_file, "parent_resources", "child_resources").should == 
			nested_routes_file("parent_resources", "child_resources")
		end
			
		it "should add a nested route when the parent exist but the nested route not" do
			childs = %w(first_childs second_childs)
			routes = nested_routes_file("parent_resources", childs.second)
			@klass.add_nested_route(routes, "parent_resources", childs.first).should ==
			nested_routes_file("parent_resources", childs)
		end
		
		it "should do nothing when the nested route already exists" do
			childs = %w(apples bananas)
			routes = nested_routes_file("parent_resources", childs)
			@klass.add_nested_route(routes, "parent_resources", childs.first).should == routes
		end
	end

	
	describe "'add_namespaced_nested_routes'" do
		it "should add a namespace and the nested routes when the namespace does not exist" do
			@klass.add_namespaced_nested_route(empty_routes_file, "admin", "parent_resources", "child_resources").should == 
			namedspace_nested_routes_file("admin", "parent_resources", "child_resources")
		end
		

		it "should add a parent and a nested routes when the parent does not exist" do 
			@klass.add_namespaced_nested_route(namedspace_routes_file("admin", []), "admin", "parent_resources", "child_resources").should == 
			namedspace_nested_routes_file("admin", "parent_resources", "child_resources")
		end
			
		it "should add a nested route when the parent exists but the nested route not" do
			childs = %w(first_childs second_childs)
			routes = namedspace_nested_routes_file("admin", "parent_resources", childs.second)
			@klass.add_namespaced_nested_route(routes, "admin", "parent_resources", childs.first).should ==
			namedspace_nested_routes_file("admin", "parent_resources", childs)
		end
		
		it "should do nothing when the nested route already exists" do
			childs = %w(apples bananas)
			routes = namedspace_nested_routes_file("admin", "parent_resources", childs)
			@klass.add_namespaced_nested_route(routes, "admin", "parent_resources", childs.first).should == routes
		end
	end
	
	describe "helper methods" do
		# it "should match namedspaced nested resource" do
		# 	routes = "map.namespace :namespace do |namespace|\n namespace.resources :parents do |parent|\n parent.resources :childs"
		# 	@klass.namespaced_nested_resource_exist?(routes, "namespace", "parents", "childs").should == true
		# end
		
		it "'sentinel_regx' should match beginning of file" do
			/#{@klass.sentinel_regx}/.should match 'ActionController::Routing::Routes.draw do |map|'
		end
		
		it "'resource_regx' should match a resource" do
			/#{@klass.resource_regx('apples', :base => 'base')}/.should match 'base.resources :apples'
		end
		
		it "'begin_of_block_regx' should match beginning of block" do
			/#{@klass.begin_of_block_regx('apple')}/.should =~ " do |apple|\n"
		end
		
		it "'resource_regx_with_block' should match a resource with a beginning of a block" do
			/#{@klass.resource_with_block_regx('apples', :base => 'base')}/.should match "base.resources :apples do |apple|\n"
		end
		
		describe "'nested_resource_regx'" do
			before(:each) do
				@routes = %(
				map.resources :products do |product|
				 	product.resources :categories
					product.resources :manufacturers
					product.resource :shops
				end
				)
			end
			
			it "should match a simple nested resource" do
				/#{@klass.nested_resource_regx('products', 'categories')}/m.should match @routes
			end
		
			it "should match a more complex nested resource" do
				/#{@klass.nested_resource_regx('products', 'manufacturers')}/m.should match @routes
			end

			it "should confirm a simple nested resource" do 
				@klass.nested_resource_exist?(@routes, 'products', 'categories').should be true
			end
			
			it "should confirm a more complex nested resource" do 
				@klass.nested_resource_exist?(@routes, 'products', 'manufacturers').should be true
			end
		end
		
		it "'namespace_regx' should match a namespace" do
			/#{@klass.namespace_regx('apple')}/.should match "map.namespace :apple do |apple|\n"
		end
		
		it "'namespace_resource_regx' should match a resource under a namespace" do
			/#{@klass.namespace_resource_regx('apple', 'bananas')}/.should match "map.namespace :apple do |apple|\n apple.resources :bananas"
		end

		it "'namespaced_resource_with_block_regx' should match a resource under a namespace with a block" do
			/#{@klass.namespaced_resource_with_block_regx('apple', 'bananas')}/.should match "map.namespace :apple do |apple|\n apple.resources :bananas do |banana|\n"
		end
		
		it "'namespaced_nested_resource_regx' should match a nested resource " do
			/#{@klass.namespaced_nested_resource_regx('apple', 'bananas', 'cars')}/.should 
				match "map.namespace :apple do |apple|\n apple.resources :bananas do |banana|\n banana.resources :cars"
		end
	end

	def routes_file(resources)
		resource_routes = [resources].flatten.map{|x| "map.resources :#{x.pluralize}"}
		empty_routes_file("\t" + resource_routes.join("\n\t") + "\n")
	end
	
	def nested_routes_file(parents, resources)
		empty_routes_file(nested_routes(parents, resources))
	end

	def namedspace_routes_file(namespace, resources)
		empty_routes_file(namedspace_routes(namespace, resources))
	end
	
	def namedspace_nested_routes_file(namespace, parents, resources)
		empty_routes_file(namedspace_routes(namespace) { nested_routes(parents, resources, :base => namespace, :indention => "\t\t") })
	end
		
	def empty_routes_file(args = "")
		"ActionController::Routing::Routes.draw do |map|\n" + 
		args + "end"
	end
	
	def nested_routes(parents, resources, options = {})
		base = options[:base] || "map"
		indention = options[:indention] || "\t"

		parents.collect do |parent|
			singular_parent = parent.singularize
			indention + "#{base}.resources :#{parent} do |#{singular_parent}|\n" +
			normal_routes(resources, :base => singular_parent, :indention => indention + "\t") +
			indention + "end\n" 
		end.to_s
	end
	
	def namedspace_routes(namespace, resources = [], options = {})
		indention = options[:indention] || "\t"

		indention + "map.namespace :#{namespace} do |#{namespace}|\n" +
		normal_routes(resources, :base => namespace, :indention => indention + "\t") +
		(block_given? ? yield : "" ) +
		indention + "end\n"
	end
	
	def normal_routes(resources, options = {})
		indention = options[:indention] || "\t"
		base = options[:base] || "map"
		
		[resources].flatten.map{|x| indention + "#{base}.resources :#{x.pluralize}\n"}.to_s
	end
end