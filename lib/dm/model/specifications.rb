module DM
  module Model
    # Using shoulda rspec matchers
    module Specifications
      
      def specify_mass_assignment
        if attributes_for(:form).any?
          "should_allow_mass_assignment_of :#{attributes_for(:form).map(&:name).join(', :')}"
        end
      end
      
      def specify_associations(options = {})
        if associations.any?
          indent = "\t"
          associations.sort.map(&:to_spec).join("\n#{indent}") + "\n"
        end
      end
      
      def specify_presence_validations(indention = 12)
        if attributes_for(:form).any?
          "should_validate_presence_of :" + attributes_for(:form).map(&:name).join(",\n#{indent(indention)}:")
        end
      end
      
      

      ##def specify_format_validations %>
      
    end
    
  end
end