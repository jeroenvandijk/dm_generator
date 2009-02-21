module DM #:nodoc:
  module Generator #:nodoc:
    module Commands #:nodoc:
      
      module Create
        def translate(models, relative_path, locale = "en")
          edit_translations(relative_path, locale) { |current_translations| build_translations(models).deep_merge(current_translations) }
        end
      end

      module Destroy
        def translate(models, relative_path, locale = "en")
          edit_translations(relative_path, locale) do |current_translations| 
            model_names = models.map(&:singular_name)
            
            current_translations["models"].reject!{|name, _| model_names.include?(name) } if current_translations["models"]
            current_translations["attributes"].reject!{|name, _| model_names.include?(name) } if current_translations["attributes"]
            
            current_translations
          end
        end
      end
      
      module List
        def translate(models, relative_path, locale = "en")
          logger.update (relative_path)
        end
      end
      
      module Utilities
        def edit_translations(relative_path, locale)
            path = destination_path(relative_path)

            translations =  File.exists?(path) ? YAML::load_file(path) : 
                                                 {locale => {"activerecord" => { "models" => {}, "attributes" =>  {} } } }

            translations[locale]["activerecord"] = yield(translations[locale]["activerecord"].clone)

            if translations[locale]["activerecord"]["models"].any?
              logger.update(relative_path) do
                File.open(path, 'wb') { |file| file.write( translations.to_yaml ) }
              end
              
            elsif File.exists?(path)
              logger.rm(relative_path) do
                File.delete(path)
              end
              
            end
        end
            
        def build_translations(models)
          model_translations = {}
          attribute_translations = {}

          models.each do |model|
            model_translations[ model.singular_name ] = model.singular_name
            attribute_translations[model.singular_name] = {}
            model.attributes.each { |attribute| attribute_translations[model.singular_name][attribute.name] = attribute.name }
          end

          { "models" => model_translations, "attributes" =>  attribute_translations }
        end
      end
    end
  end
end

%w(Create Destroy List).each do |action|
  eval("DM::Generator::Commands::#{action}").send :include, DM::Generator::Commands::Utilities
end

Rails::Generator::Commands::Create.send   :include,  DM::Generator::Commands::Create
Rails::Generator::Commands::Destroy.send  :include,  DM::Generator::Commands::Destroy
Rails::Generator::Commands::List.send     :include,  DM::Generator::Commands::List