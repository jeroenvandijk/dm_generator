module DM
  module Model
    module Associations
       
      # Parent methods are used for the make_resourceful template, 
      # but could be used for any nested resource setup.     
      def parents
        @parents ||= associations.reject { |association| not association.is_parent_relation? }.map{|x| ":#{x.name.singularize}" }
      end

      def has_parents?
        not parents.empty?
      end

      def habtm_associations
        @habtm_associations ||= associations.reject { |association| association.type.to_s != "has_and_belongs_to_many" }
      end
      
      def belongs_to_associations
        @belongs_to_associations ||= associations.reject { |association| association.type.to_s != "belongs_to" }
      end
      
      # # Is used in the fixture template. It includes habtm and has_many associations
      # # with the exception of has_many => through because this is a derived association.
      # def collections
      #   @collection ||= associations.reject do |association| 
      #     not (association.type.to_s =~ /has_many|has_and_belongs_to_many/ && association.options[:through].nil?)
      #   end
      # end
      
      # def collection_names
      #   collections.map(&:name)
      # end
      
      def add_associations(options = {})
        indent = "\t"
        associations.sort.map(&:to_ar).join("\n#{indent}") + "\n"
      end

      
    end
  end
end