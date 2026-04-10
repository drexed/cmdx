# frozen_string_literal: true

module CMDx
  # Railtie for Rails integration.
  # Loads locale files and sets up the Rails logger.
  class Railtie < Rails::Railtie

    initializer "cmdx.i18n" do
      if defined?(I18n)
        locale_path = File.expand_path("../../locales/*.yml", __dir__)
        I18n.load_path += Dir[locale_path]
      end
    end

    initializer "cmdx.logger" do
      config.after_initialize do
        CMDx.configuration.logger ||= Rails.logger
      end
    end

  end
end
