# frozen_string_literal: true

module Cmdx
  # Rails generator that scaffolds the CMDx initializer at
  # `config/initializers/cmdx.rb`. The initializer template seeds global
  # {CMDx.configuration} defaults (middlewares, callbacks, coercions,
  # validators, telemetry) that all tasks inherit from.
  #
  # Invoked via `rails generate cmdx:install`.
  class InstallGenerator < Rails::Generators::Base

    source_root File.expand_path("templates", __dir__)

    desc "Creates CMDx initializer with global configuration settings"

    # Copies the initializer template into the host application's
    # `config/initializers` directory.
    #
    # @return [void]
    def copy_initializer_file
      copy_file("install.rb", "config/initializers/cmdx.rb")
    end

  end
end
