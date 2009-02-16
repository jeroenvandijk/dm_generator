module DM
  module ModelHelper
    # TODO add api comments

    def form_reference;     "f"; end

    # TODO make this work as a block
    # def define_helper;      "module #{controller_class_name}Helper" + (block_given? ? yield.to_s : "") + "\nend"; end
    # def define_observer;    "def #{class_name}Observer" + (block_given? ? yield.to_s : "") + "\nend"; end
    # def define_mailer;      "class #{controller_class_name}Mailer < ActionMailer::Base" + (block_given? ? yield.to_s : "") + "\nend"; end
    # def define_controller;  "class #{controller_class_name}Controller < ApplicationController" + (block_given? ? yield.to_s : "") + "\nend"; end
    # def define_model;       "class #{class_name} < ActiveRecord::Base" + (block_given? ? yield.to_s : "") + "\nend"; end
    # def make_resourceful;   "make_resourceful do\n#{indent * 2}actions :all\n"+ (has_parents? ? "#{indent * 2}belongs_to: #{parents.join(',')}\n" : '') + "#{indent}end"; end
    # def form_for;           block_in_template{ "form_for #{form_for_args} do |#{form_reference}|" } + (block_given? ? yield.to_s : "") + "\n#{block_in_template{"end"}}"; end


    def define_helper;      "module #{controller_class_name}Helper\nend"; end
    def define_observer;    "def #{class_name}Observer\nend"; end
    def define_mailer;      "class #{controller_class_name}Mailer < ActionMailer::Base\nend"; end
    def define_controller;  "class #{controller_class_name}Controller < ApplicationController"; end
    def define_model;       "class #{class_name} < ActiveRecord::Base"; end
    def make_resourceful;   "make_resourceful do\n#{indent * 2}actions :all\n"+ (has_parents? ? "\n#{indent * 2}belongs_to #{parents.join(', ')}\n" : '') + "#{indent}end"; end


    def form_for;           block_in_template{ "form_for #{form_for_args} do |#{form_reference}|" } ; end#+ (block_given? ? yield.to_s : "") + "\n#{block_in_template{"end"}}"; end

    def helper_prefix
      @helper_prefix ||= namespaces.empty? ? '' : namespaces.join("_") + '_'
    end

    def form_for_args
      args = namespace_symbols + (has_parent? ? ["parent_object"] : []) + [singular_name]
      args.size == 1 ? args.first : '[' + args.join(', ') + ']'
    end
 
    # Render partial exploits the new rails render feature:
    # - render @article  # Equivalent of render :partial => 'articles/_article', :object => @article
    # - render @articles # Equivalent of render :partial => 'articles/_article', :collection => @articles  
    def render_partial(objects)
     assign_in_template { "render #{objects}" }
    end

    def render_form
      assign_in_template { "render :partial => :form, :locals => {:#{singular_name} => #{singular_name} }" }
    end

    # Render form use the field_for template too include the form of the nested object
    def render_fields_for(object)
      prefix = object.singularize == singular_name ? '' : object.pluralize + '/'
      assign_in_template { "#{form_reference}.fields_for {|fields| render :partial => '#{prefix}fields_for', :locals => {:#{form_reference} => fields} }"  }
    end

    # def m_r_link_to(action, text)
    #   case action
    #   when
    #     
    #   end
    # end

    def link_to(action, options = {}) 
      type = options[:type] || "path"
      template = options[:template] || "default"
      instance = template == "partial" ? singular_name : "@#{singular_name}"
    
      assign_in_template do
        "link_to translate_for('#{singular_name}.#{template}.link_to_#{action}'), " +
        case action 
        when :new      : "new_#{helper_prefix}#{singular_name}_#{type}"
        when :edit     : "edit_#{helper_prefix}#{singular_name}_#{type}(#{instance})"
        when :index    : "#{helper_prefix}#{plural_name}_#{type}"
        when :show     : "#{helper_prefix}#{singular_name}_#{type}(#{instance})"
        when :destroy  : "#{helper_prefix}#{singular_name}_#{type}(#{instance}), :confirm => translate_for('#{singular_name}.#{template}.confirm_destroy_message'), :method => :delete"
        end
      end
    end
    
    
    # translations
    def page_title(action = "default")
      assign_in_template{ "@page_title = translate_for('#{singular_name}.#{action}.title')" }
    end
    
    def save_form_button
      assign_in_template { "#{form_reference}.submit translate_save_for(:#{singular_name})" }
    end
    
    def error_messages
      assign_in_template { "#{form_reference}.error_messages" }
    end
    
    
    # TODO write how this can be overwritten so that it can be used for haml
    def block_in_template;                "<% " + yield + " %>"; end
    def assign_in_template;               "<%= " + yield + " %>"; end

  end
end 