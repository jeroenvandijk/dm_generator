module DM
  module Model
    module Helpers
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
        args = namespace_symbols + (has_parents? ? ["parent_object"] : []) + [singular_name]
        args.size == 1 ? args.first : '[' + args.join(', ') + ']'
      end
 
      # Render partial exploits the new rails render feature:
      # - render @article  # Equivalent of render :partial => 'articles/_article', :object => @article
      # - render @articles # Equivalent of render :partial => 'articles/_article', :collection => @articles  
      def render_partial(objects)
        if objects == objects.singularize
          assign_in_template { "render :partial => #{objects}, :object => #{objects} "}
        else
          assign_in_template { "render :partial => #{objects}, :collection => #{objects} "}
        end


       # assign_in_template { "render #{objects}" } # 2.3
      end

      def render_form
        assign_in_template { "render :partial => 'form', :locals => {:#{singular_name} => @#{singular_name} }" }
      end
    
      def render_form_fields
        assign_in_template { "render :partial => 'form_fields', :locals => {:#{form_reference} => #{form_reference} }" }
      end

      # Render form use the field_for template too include the form of the nested object
      def render_fields_for(object)
        prefix = object.singularize == singular_name ? '' : object.pluralize + '/'
        assign_in_template { "#{form_reference}.fields_for {|fields| render :partial => '#{prefix}form_fields', :locals => {:#{form_reference} => fields} }"  }
      end

      def link_to(action, options = {}) 
        type = options[:type] || "path"
        template = options[:template] || "default"
        instance = template.to_sym == :partial ? singular_name : "@#{singular_name}"
    
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
      
      def make_resourceful_link_to(action, options = {}) 
        type = options[:type] || "path"
        template = options[:template] || "default"

        singular = "nested_object"
        plural = "nested_objects"
        instance = template.to_sym == :partial ? "(#{singular_name})" : ""  
    
        assign_in_template do
          %{content_tag :div, link_to( translate_for("#{singular_name}.#{template}.link_to_#{action}"), } +
          case action 
          when :new      : "new_#{singular}_#{type}"
          when :edit     : "edit_#{singular}_#{type}#{instance}"
          when :index    : "#{plural}_#{type}"
          when :show     : "#{singular}_#{type}#{instance}"
          when :destroy  : "#{singular}_#{type}#{instance}, :confirm => translate_for('#{singular_name}.#{template}.confirm_destroy_message'), :method => :delete"
          end + %{ ), :class => "link_to_#{action}"}
        end
      end
    
			def will_paginate(options = {})
				assign_in_template{ "will_paginate @#{plural_name}#{options_to_template(options)}" } if self.options[:use_pagination]
			end
			
			# Only support hashes with string options
			def options_to_template(*args)
				options = args.extract_options!
				prefix = args.shift || ""
				options.empty? ? "" : prefix + options.to_a.collect { |pair| ":#{pair.first.to_s} => #{pair.second.to_s}" }.join(",")
			end
    
      # translations
      # def page_title(action = "default")
      #   assign_in_template{ "content_tag :h1, @page_title = translate_for('#{singular_name}.#{action}.title').humanize" }
      # end
      
      # translations
      def page_title(action = "default")
        assign_in_template{ "title_for(:#{singular_name}, :#{action})" }
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
end 