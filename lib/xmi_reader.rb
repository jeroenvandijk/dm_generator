require 'rubygems'
require 'hpricot'
require 'activesupport'

# This class translates a Uml model in xmi format to a valid dm_generator datamodel format
# This class import xmi (1.4) exported from ArgoUml (0.26.2) (http://www.argouml.org),
# has not been tested with other programs or other versions
class XmiReader
  
  def initialize(xmi_file)
    @doc = Hpricot.XML(open(xmi_file))

    @type_prefix = 'http://argouml.org/profiles/uml14/default-uml14.xmi#'
    @types = load_types
    @models = load_models
    load_associations
    remove_empty_models
  end
  
  def to_h
    @to_h ||= { "models" => models }
  end

  def to_yaml
    to_h.to_yaml
  end
  
  private
  
  attr_reader :doc, :type_prefix, :models, :types
  
  def load_types
    types = {}
    # Define types that are native to xmi
    types['-84-17--56-5-43645a83:11466542d86:-8000:000000000000087E']    = "string"
    types['-84-17--56-5-43645a83:11466542d86:-8000:000000000000087C']    = "integer"
    types['-84-17--56-5-43645a83:11466542d86:-8000:0000000000000880']    = "boolean"

    # Gather all names and types of class in the model
    for_each_uml_class { |klass, name| types[ klass["xmi.id"] ] = name }

    types
  end

  # Remove all empty models  
  def remove_empty_models
    models.reject! { |_, properties| properties["attributes"].blank? && properties["associations"].blank? }
  end
  
  def load_models    
    models = {}

    # # Loop over all UML:Class elements and extract their attributes
   for_each_uml_class do |klass, name|
      
      model = models[name] = {}
      model["attributes"] = klass.search("UML:Attribute").collect do |attribute|

        name = attribute['name']      

        # See if the attribute has a predefined types (Integer, String)
        datatype = attribute.at("UML:DataType")
        type = types[ datatype["href"].gsub(type_prefix, '') ] unless datatype.nil?
        
        # Other wise go for the default          
        type ||= types[ attribute.at("UML:Class")  ["xmi.idref"] ]
        
        # Collect the hash
        {name => type}
      end        
    end
    models
  end
  
  def for_each_uml_class
    doc.search("UML:Class").each do |klass|
      name = klass["name"]
      yield(klass, name && name.downcase.singularize)
    end
  end
  
  def load_associations
    doc.search("UML:Association").each do |pair|
      relation = pair.search("UML:Class").collect { |klass| types[ klass["xmi.idref"] ] }
     
      pair.search("UML:MultiplicityRange").each_with_index do |range, i|
        associations = models[ relation[1-i]  ]["associations"] ||= []
        associations << translate_uml_range(relation[i], range["lower"], range["upper"])
      end
    end
    # Now we've gather all associations see if we need to change and add some
    reinterpret_associations
  end
  
  
  # The range is translated as follows:
  # - -1 indicates a '*' which refers to a has_many relationship
  # - 0 indicates a optional relationship such as has_one
  # - The default case in which none of the above apply suggests a belongs_to relation
  def translate_uml_range(*args)
    name, *range = args

    if range.include?('-1')
      { name.pluralize => "has_many" }
    elsif range.include?('0')
      { name => "has_one" }
    else
      { name => "belongs_to" }
    end
  end
  
  # See if we can find hidden has_and_belongs_to_many and has_many :through associations
  def reinterpret_associations
    # raise models.keys.inspect
    models.each_pair do |a, properties|
      
      if associations = properties["associations"]
        associations = associations.collect do |association|

          b, relation_of_a_with_b, options = association.to_a.flatten

          # We are only interested in has_many associations, because they could be a habtm relation
          #  or could imply a has_many through association
          if relation_of_a_with_b == "has_many" && !(options && options["through"])
            relation_of_b_with_a = find_association_type_of(b, a)

            # raise  b  + find_association_type_of(b, a)  + a + models.to_yaml

            # If 'b => a' is also a has_many or habtm we need to change the type of 'a => b'
            if relation_of_b_with_a =~ /has_many|has_and_belongs_to_many/
              relation_of_a_with_b = "has_and_belongs_to_many"

            # If 'b => a' is belongs_to there could be a has_many through relation with another model
            elsif relation_of_b_with_a == "belongs_to"

              find_associations_of(b).each do |association|
                c, relation_of_b_with_c = association.to_a.first
                
                # If 'b => c' is a belongs_to and 'c => b' is a has_many, we found a has_many through relation 'a => c'
                if c != a && relation_of_b_with_c == "belongs_to"
                  if find_association_type_of(c, b) == "has_many"
                    # We need to remember instead of adding associations because we are in a collect loop. 
                    # Which would otherwise overwrite our changes

                    remember_association_for(a, c.pluralize, "has_many", :through => b)       
                  end
                end
              end
              
            end
          end  
          { b => relation_of_a_with_b }
        end

        # Add implied associations that we have memorized
        properties["associations"] = associations + retrieve_associations_for(a)
      end
    end
  end
  
  # Memory of associations that need to be added
  def retrieve_associations_for(model)
    @memory ||= {}
    @memory[model] ||= {}
    @memory[model]["associations"] ||= []    
  end
  
  # Memorize to add associations
  def remember_association_for(model, name, type, options = {})
    associations = retrieve_associations_for(model)

    association = {name => type}
    association["options"] = options unless options.empty?

    associations << association
  end
  
  # Finds the association list of the given model model
  def find_associations_of(_model) 
    model = _model.singularize # to be certain we won't search for plural models
    associations = models[model] && models[model]["associations"]    
  end
  
  # Somehow i got a bug here, TODO add tests
  def find_association_type_of(source, _target)
    target = _target.singularize 
    
    find_associations_of(source.singularize).each do |association| 
      other, type = association.to_a.first
      return type if other.singularize == target
    end
    
    # Nothing found
    return nil
  end
end