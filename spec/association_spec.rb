require File.dirname(__FILE__) + '/spec_helper'

describe DM::Association do
  before :each do
    @options = {"through" => "his_intellect", ":dependent" => "not_very_much" }
    @name = "jeroen"
    @type = "belongs_to_the_small_group_of_geniuses"
    @association = DM::Association.new(@name, @type, @options)
    
  end

  it "should return the correct name" do
    @association.name.should eql @name
  end
    
  it "should return the correct type" do
    @association.type.should eql @type
  end

  it "should return the right options" do
    @association.options.should == @options
  end

  it "should sort on name with same relation" do
    association1 = DM::Association.new("a", "belongs_to")
    association2 = DM::Association.new("b", "belongs_to")
    association1.<=>(association2).should eql -1
  end
  
  it "should sort on name with same relation" do
    association1 = DM::Association.new("a", "has_many")
    association2 = DM::Association.new("b", "belongs_to")
    association1.<=>(association2).should eql 1
  end
  
  it "should list has_many => through above has_many" do
    association1 = DM::Association.new("a", "has_many", :through => "other")
    association2 = DM::Association.new("a", "has_many")
    association1.<=>(association2).should eql 1
  end
  
  describe "singular" do
    it "should be true for type belongs_to" do
      association = DM::Association.new(@name, "belongs_to", @options)
      association.is_singular?.should be true
    end
    
    it "should be true for type has_one" do
      association = DM::Association.new(@name, "has_one", @options)
      association.is_singular?.should be true      
    end
  end
  
  describe "plural?" do
    it "should be true for type has_many" do
      association = DM::Association.new(@name, "has_many", @options)
      association.is_singular?.should be false      
    end

    it "should be true for type has_and_belongs_to_many" do
      association = DM::Association.new(@name, "has_and_belongs_to_many", @options)
      association.is_singular?.should be false
    end
  end
  
  describe "parent relation" do
    it "should be true for type belongs_to" do
      association = DM::Association.new(@name, "belongs_to", @options)
      association.is_parent_relation?.should be true
    end
    
    it "should be true for type has_and_belongs_to_many" do
      association = DM::Association.new(@name, "has_and_belongs_to_many", @options)
      association.is_parent_relation?.should be true
    end
  end
  
  describe "activerecord format" do
    it "should be plural, when plural" do
      association = DM::Association.new(@name, "has_and_belongs_to_many", {})
      association.to_ar.should eql "has_and_belongs_to_many :#{@name.pluralize}"
    end
    
    it "should be singular, when singular" do
      association = DM::Association.new(@name, "belongs_to", {})
      association.to_ar.should eql "belongs_to :#{@name.singularize}"
    end
    it "should include all options" do
      association = DM::Association.new(@name, "belongs_to", :test1 => 1, :test2 => 2)
      association.to_ar.should eql "belongs_to :#{@name.singularize}, :test1 => 1, :test2 => 2"
    end
    it "should put option through in front" do
      association = DM::Association.new(@name, "has_one", :option => 1, :through => :geniuses)
      association.to_ar.should eql "has_one :#{@name.singularize}, :through => :geniuses, :option => 1"      
    end
  end
  
end