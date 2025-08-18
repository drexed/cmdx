# frozen_string_literal: true

module Cmdx
  # Generates CMDx initializer file for Rails applications
  #
  # This generator creates a configuration initializer that sets up global
  # CMDx settings for the Rails application. It copies a pre-configured
  # initializer template to the standard Rails initializers directory.
  class InstallGenerator < Rails::Generators::Base

    source_root File.expand_path("templates", __dir__)

    desc "Creates CMDx initializer with global configuration settings"

    # Copies the CMDx initializer template to the Rails application
    #
    # Creates a new initializer file at `config/initializers/cmdx.rb` containing
    # the default CMDx configuration settings. This allows applications to
    # customize global CMDx behavior through the standard Rails configuration
    # pattern.
    #
    # @return [void]
    #
    # @example Basic usage
    #   rails generate cmdx:install
    #
    # @example Custom initializer location
    #   generator.copy_initializer_file
    #   # => Creates config/initializers/cmdx.rb
    def copy_initializer_file
      copy_file("install.rb", "config/initializers/cmdx.rb")
    end

  end
end
