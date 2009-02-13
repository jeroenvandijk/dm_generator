module DM
  class Association
    attr_reader :name, :type, :options, :templates

    def initialize(name, type, options = {})
      @name, @type, @options = name, type, HashWithIndifferentAccess.new(options.symbolize_keys)
      @templates = options[:include_in] || []
    end
    
    # Return the association for to define it in a model
    def to_ar
      "#{type} :" + (is_plural? ? name.pluralize : name.singularize) + (options.empty? ? '' : ", #{options_to_ar}" )
    end
    
    def options_to_ar
      option_list = []
      sorted_options = options.sort
      sorted_options.each do |option, value|
        declaration = ":#{option} => #{value.is_a?(Symbol) ? ':' : ''}#{value}"

        if option.to_sym == :through
          option_list = [declaration] + option_list
        else
          option_list << declaration
        end
      end

      option_list.join(', ') 
    end
    
    def is_plural?
      not is_singular?
    end
    
    def is_singular?     
      @singular ||= %(has_one belongs_to).include?(type.to_s)
    end
    
    def is_parent_relation?       
      @child ||= %(belongs_to has_and_belongs_to_many).include?(type.to_s)
    end
            
    # implement comparison operator so we can sort
    def <=>(other)
      if type != other.type
        type <=> other.type
      elsif options[:through].nil? == other.options[:through].nil?
        name <=> other.name
      else
        options[:through].to_s <=> other.options[:through].to_s
      end
    end
  end
  
end