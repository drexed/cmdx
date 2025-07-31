# frozen_string_literal: true

module CMDx
  class Railtie < Rails::Railtie

    railtie_name :cmdx

    initializer("cmdx.configure_locales") do |app|
      Array(app.config.i18n.available_locales).each do |locale|
        path = CMDx.gem_path.join("locales/#{locale}.yml")
        next unless File.file?(path)

        I18n.load_path << path
      end

      I18n.reload!
    end

  end
end
