# frozen_string_literal: true

module CMDx
  class Railtie < Rails::Railtie

    railtie_name :cmdx

    initializer("cmdx.configure_locales") do |app|
      Array(app.config.i18n.available_locales).each do |locale|
        path = File.expand_path("../../../lib/locales/#{locale}.yml", __FILE__)
        next unless File.file?(path)

        I18n.load_path << path
      end

      I18n.reload!
    end

    initializer("cmdx.configure_rails_auto_load_paths") do |app|
      app.config.autoload_paths += %w[app/cmds]

      types = %w[workflows tasks]
      app.autoloaders.each do |autoloader|
        types.each do |concept|
          dir = app.root.join("app/cmds/#{concept}")
          autoloader.collapse(dir)
        end
      end
    end

  end
end
