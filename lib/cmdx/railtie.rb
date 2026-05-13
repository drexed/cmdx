# frozen_string_literal: true

module CMDx
  # Rails integration. Loaded only when `Rails::Railtie` is defined. Wires the
  # app's `I18n.load_path` so CMDx locale files for each available locale are
  # available, and points the CMDx logger and backtrace cleaner at Rails.
  class Railtie < Rails::Railtie

    railtie_name :cmdx

    initializer("cmdx.configure_rails") do |app|
      available_locales = app.config.i18n.available_locales.join(",")
      available_locales = "*" if available_locales.empty?
      locale_path = File.expand_path("../locales/{#{available_locales}}.yml", __dir__)
      ::I18n.load_path += Dir[locale_path]

      CMDx.configure do |config|
        config.logger = Rails.logger
        config.backtrace_cleaner = ->(bt) { Rails.backtrace_cleaner.clean(bt) }
      end
    end

  end
end
