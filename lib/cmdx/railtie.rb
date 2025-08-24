# frozen_string_literal: true

module CMDx
  # Rails integration class that automatically configures CMDx when the Rails
  # application initializes. Handles locale configuration and I18n setup.
  class Railtie < Rails::Railtie

    railtie_name :cmdx

    # Configures CMDx locales during Rails application initialization.
    #
    # Iterates through available locales from the Rails configuration and loads
    # corresponding CMDx locale files. Reloads the I18n system to ensure
    # all locales are properly registered.
    #
    # @param app [Rails::Application] the Rails application instance
    #
    # @raise [LoadError] if locale files cannot be loaded
    #
    # @example
    #   # This initializer runs automatically when Rails starts
    #   # It will load locales like en.yml, es.yml, fr.yml if they exist
    #   # in the CMDx gem's locales directory
    initializer("cmdx.configure_locales") do |app|
      Array(app.config.i18n.available_locales).each do |locale|
        path = CMDx.gem_path.join("lib/locales/#{locale}.yml")
        next unless File.file?(path)

        ::I18n.load_path << path
      end

      ::I18n.reload!
    end

  end
end
