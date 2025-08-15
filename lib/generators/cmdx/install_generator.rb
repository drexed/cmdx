# frozen_string_literal: true

module Cmdx
  # Rails generator for creating CMDx initializer configuration file.
  #
  # This generator creates a new initializer file at config/initializers/cmdx.rb
  # with global configuration settings for the CMDx framework. The generated
  # initializer provides a centralized location for configuring CMDx behavior
  # such as logging, error handling, and default parameter settings.
  class InstallGenerator < Rails::Generators::Base

    source_root File.expand_path("templates", __dir__)

    desc "Creates CMDx initializer with global configuration settings"

    # Copies the CMDx initializer template to the Rails application.
    #
    # Creates a new initializer file at config/initializers/cmdx.rb by copying
    # the install.rb template. This file contains the default CMDx configuration
    # that can be customized for the specific application needs.
    #
    # @raise [Thor::Error] if the destination file cannot be created or already exists without force
    #
    # @example Generate CMDx initializer
    #   rails generate cmdx:install
    #   # Creates config/initializers/cmdx.rb
    def copy_initializer_file
      copy_file("install.rb", "config/initializers/cmdx.rb")
    end

  end
end
