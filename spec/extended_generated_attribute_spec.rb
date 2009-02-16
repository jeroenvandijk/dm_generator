require File.dirname(__FILE__) + '/spec_helper'

describe DM::ExtendedGeneratedAttribute do
  before :each do 
    @name = "new_attribute"
    @type = "new_type"
    @all_templates = %w(form show index migrations)
    @options = {:only => @templates}

    DM::ExtendedGeneratedAttribute.stub(:native_types).returns(@native_types)
    DM::ExtendedGeneratedAttribute.stub(:native?).returns(:true)

    @attribute = DM::ExtendedGeneratedAttribute.new(@name, @type, @options )
    
    @native_types = %w(string integer)
  end
  
  it "should have the given name"
  it "should have the given type"
  
  
  
  describe "templates" do
    it "should have all the templates when no option is given" do
      @attribute.templates.should eql @all_templates
    end
    it "should only have form" do

      @attribute = DM::ExtendedGeneratedAttribute(@name, @type, @options )
      
    end
    
    
  end
end