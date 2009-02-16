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
      
      # Collection associations are use in the fixture template. It includes habtm and has_many associations
      # with the exception of has_many => through because this is a derived association.
      def collection_associations
        @collection_associations ||= associations.reject do |association| 
          not (association.type.to_s =~ /has_many|has_and_belongs_to_many/ && association.options[:through].nil?)
        end
      end

      
    end
  end
end