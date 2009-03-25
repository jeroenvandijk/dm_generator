module DM
  module Model
    # Using shoulda rspec matchers
    module Specifications
      
      def specify_mass_assignment(indention = 19)
				attributes_for_mass_assignment = attributes_for(:form).map(&:name)
				attributes_not_for_mass_assignment = attributes.map(&:name) - attributes_for_mass_assignment

				declarations = []
				declarations << "xit { should allow_mass_assignment_of(:#{attributes_for_mass_assignment.join(",\n#{indent(indention)} :")}) }" if attributes_for_mass_assignment.any?
      	declarations << "xit { should_not allow_mass_assignment_of(:#{attributes_not_for_mass_assignment.join(",\n#{indent(indention + 2)} :")}) }" if attributes_not_for_mass_assignment.any?
				declarations.join("\n\n\t")
      end
      
      def specify_associations(options = {})
        if associations.any?
          indent = "\t"
          associations.sort.map(&:to_spec).join("\n#{indent}") + "\n"
        end
      end
      
      def specify_presence_validations(indention = 17)
        if attributes_for(:form).any?
          "xit { should validate_presence_of(:" + attributes_for(:form).map(&:name).join(",\n#{indent(indention)} :") + ") }"
        end
      end
      
      

      ##def specify_format_validations %>
      
    end
    
  end
end