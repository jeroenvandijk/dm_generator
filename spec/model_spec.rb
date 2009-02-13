require File.dirname(__FILE__) + '/spec_helper'

describe DM::Reader do
	it "should load all models with name spaces"
	it "should raise errors when the structure is incorrect"
	
end

def setup_model
  options = {} 
  options[:supported_associations] = %w(belongs_to has_many has_and_belongs_to_many has_one)
  options[:supported_association_options] = %w(through dependent)
  options[:parent_associations] = %w(belongs_to has_and_belongs_to_many)
	options[:view_templates] = %w(index show new edit _form _partial)
	DM::Model.add_options(options)
end

describe DM::Model, "basics" do
    before :each do
      setup_model
      @model_name = "special_tree"
      @class_name = @model_name.camelize
      @controller_class_name = @model_name.pluralize.camelize
      yaml = <<END_OF_YAML
  associations: []
  attributes: []

END_OF_YAML

  		@model_hash = YAML::load(yaml).symbolize_keys!
  		@model = DM::Model.new(@model_name, @model_hash, :namespaces => [])
  	end
  
	it "should give the singular name of the resource with #singular_name" do
		@model.singular_name.should eql @model_name.singularize
	end
	
	it "should give the plural name of the resource with #plural_name" do
    @model.plural_name.should eql @model_name.pluralize
  end
	
	it "should give the model class name with #class_name" do
	  @model.class_name.should eql @model_name.camelize
  end
	
	it "should give the model file name with #file_name" do
	  @model.file_name.should eql @model_name.underscore
  end
	
  describe "indention" do
		it "should be a tab when indention is set to be a tab with #indent"
		it "should be a two-spaces when indention is set to be a tab with #indent"
	end
	
	
	describe "attributes" do
		
	end
	
	
	describe ", for activerecord" do

  end
end

describe DM::Model, "without namespaces or parents" do
  before :each do
    setup_model
    @model_name = "special_tree"
    @class_name = @model_name.camelize
    @controller_class_name = @model_name.pluralize.camelize
    yaml = <<END_OF_YAML
associations: []
attributes: []
    
END_OF_YAML
		@model_hash = YAML::load(yaml).symbolize_keys!
		DM::Model.add_options(options)
		@model = DM::Model.new(@model_name, @model_hash, :namespaces => [])
		@indent = "\t"
	end
	
	describe "basics" do
		it "should give the controller class name with #controller_class_name" do
  	  @model.controller_class_name.should eql @model_name.pluralize.camelize
    end

  	it "should give the controller file name with #controller_file_name" do
  	  @model.controller_file_name.should eql @model_name.pluralize.underscore
    end
  end
	
	describe "template methods" do
	
	  describe "define_methods" do
		  it "should define a helper with #define_helper" do
  		  @model.define_helper{}.should eql "module #{@controller_class_name}Helper\nend"
  	  end
  		it "should define a observer with #define_observer" do
  		  @model.define_observer{}.should eql "def #{@class_name}Observer\nend"
  	  end
  		it "should define a ActionMailer with #define_mailer" do
  		  @model.define_mailer{}.should eql "class #{@controller_class_name}Mailer < ActionMailer::Base\nend"
  	  end

  		it "should define a model with #define_model" do
  		  @model.define_model{}.should eql "class #{@class_name} < ActiveRecord::Base\nend"
  	  end

  		it "should define a controller with #define_controller" do
  		  @model.define_controller{}.should eql "class #{@controller_class_name}Controller < ApplicationController\nend"
  	  end
  		it "should declare make_resourceful without parents" do
  		  @model.make_resourceful.should eql "make_resourceful do\n#{@indent * 2}actions :all\n#{@indent * 2}end"
  	  end
    end
    
    # TODO do this for partial and not a partial
		describe "ActionView methods" do
			it "#form_for should define a form" do
			  @model.form_for{}.should eql "<% form_for @#{@model_name} do |f| %>\n<% end %>"
		  end
			it "should define a link_to new with #link_to(:new)" do
			  @model.link_to(:new).should eql "<%= link_to translate_for('#{@model_name}.default.link_to_new'), new_#{@model_name}_path %>"
		  end
			it "should define a link_to edit with #link_to(:edit)" do
			  @model.link_to(:edit).should eql "<%= link_to translate_for('#{@model_name}.default.link_to_edit'), edit_#{@model_name}_path(@#{@model_name}) %>"
		  end
		  
		  it "should define a link_to edit with #link_to(:edit, :partial => ) a local variable" do
        @model.link_to(:edit, :partial => "partial").should eql "<%= link_to translate_for('#{@model_name}.partial.link_to_edit'), edit_#{@model_name}_path(#{@model_name}) %>"
	    end
			it "should define a link_to destroy with #link_to(:destroy)" do
			  @model.link_to(:destroy).should eql "<%= link_to translate_for('#{@model_name}.default.link_to_destroy'), @#{@model_name}, :confirm => translate_for('#{@model_name}.default.confirm_destroy_message'), :method => :delete %>"
		  end
			it "should define a link_to index with #link_to(:index)" do
			  @model.link_to(:index).should eql "<%= link_to translate_for('#{@model_name}.default.link_to_index'), #{@model_name.pluralize}_path %>"
		  end
			it "should define a link_to show with #link_to(:show)" do
        @model.link_to(:show).should eql "<%= link_to translate_for('#{@model_name}.default.link_to_show'), @#{@model_name} %>"
		  end
		end
		
		describe "migration methods" do
			it "should define a model migration with #define_model migration"
			it "should define a habtm migration with #define_habtm migration"
		end

	end	
	it "should return no nested class path with #controller_class_path" do
	  @model.controller_class_path.should eql ''
  end
end
	
describe DM::Model, "with associations" do
  before :each do
    setup_model
    @model_name = "special_tree"
    @class_name = @model_name.camelize
    @controller_class_name = @model_name.pluralize.camelize
    yaml = <<END_OF_YAML
associations:
  - branches: has_many
  - leaves: has_many
    option:
      through: branches
attributes: []

END_OF_YAML
		@model_hash = YAML::load(yaml).symbolize_keys!
		DM::Model.add_options(options)
		@model = DM::Model.new(@model_name, @model_hash, :namespaces => [])
		@indent = "\t"
	end
  
  describe ", for activerecord" do
    it "should return proper valdidations for association_validations with #association_validations" do

    end
  end

  describe ", for make_resourceful" do 
    it "should include parent parents" do
      @model.make_resourceful.should match /make_resourceful do\n\s+actions :all\n\s+belongs_to :branch, :leave\n\s+end/
    end
  end
end


	
describe DM::Model, "with namespaces" do
  before :each do
    setup_model
    @model_name = "special_tree"
    @class_name = @model_name.camelize
    @controller_class_name = @model_name.pluralize.camelize
    yaml = <<END_OF_YAML
associations: []
attributes: []

END_OF_YAML
  	@model_hash = YAML::load(yaml).symbolize_keys!
  	DM::Model.add_options(options)
  	@namespaces = [:admin, :sub_admin]
  	@model = DM::Model.new(@model_name, @model_hash, :namespaces => @namespaces)
  	@indent = "\t"
  	@controller_class_path = (@namespaces).join("/")
  	@controller_class_name = (@controller_class_path + "/" + @model_name.pluralize).camelize

  end
  
  describe "basics" do
		it "should give the controller class name with #controller_class_name" do
  	  @model.controller_class_name.should eql @controller_class_name
    end

  	it "should give the controller file name with #controller_file_name" do
  	  @model.controller_class_path.should eql @controller_class_path
    end
    
    it "should return namespaces with #namespaces" do
      @model.namespaces.should be @namespaces
    end
  end
end

