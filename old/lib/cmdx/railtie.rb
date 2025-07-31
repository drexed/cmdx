# frozen_string_literal: true

module CMDx
  # Rails integration for CMDx framework.
  #
  # Provides Rails-specific configuration including internationalization
  # locale loading and autoload path configuration for CMDx workflows and tasks.
  class Railtie < Rails::Railtie

    railtie_name :cmdx

    # Configure internationalization locales for CMDx.
    #
    # Loads available locale files from the CMDx locales directory
    # and adds them to the I18n load path. Only loads locales that
    # are configured as available in the Rails application.
    #
    # @param app [Rails::Application] the Rails application instance
    #
    # @return [void]
    #
    # @raise [StandardError] if I18n reload fails
    #
    # @example Configure locales during Rails initialization
    #   # This initializer runs automatically during Rails boot
    #   # when CMDx is included in a Rails application
    initializer("cmdx.configure_locales") do |app|
      Array(app.config.i18n.available_locales).each do |locale|
        path = File.expand_path("../../../lib/locales/#{locale}.yml", __FILE__)
        next unless File.file?(path)

        I18n.load_path << path
      end

      I18n.reload!
    end

    # Configure Rails autoload paths for CMDx components.
    #
    # Adds the app/cmds directory to Rails autoload paths and configures
    # autoloaders to collapse the workflows and tasks subdirectories.
    # This enables Rails to automatically load CMDx workflows and tasks
    # from the conventional directory structure.
    #
    # @param app [Rails::Application] the Rails application instance
    #
    # @return [void]
    #
    # @raise [StandardError] if autoloader configuration fails
    #
    # @example Configure autoload paths during Rails initialization
    #   # This initializer runs automatically during Rails boot
    #   # Enables loading of:
    #   # - app/cmds/workflows/my_workflow.rb
    #   # - app/cmds/tasks/my_task.rb
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
