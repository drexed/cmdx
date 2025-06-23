# frozen_string_literal: true

module Cmdx
  ##
  # Rails generator for creating CMDx initializer configuration.
  #
  # This generator creates a configuration initializer file that sets up
  # global CMDx settings for task execution, batch processing, logging,
  # and error handling behaviors.
  #
  # The generated initializer provides sensible defaults that can be
  # customized for specific application requirements.
  #
  # @example Generate CMDx initializer
  #   rails generate cmdx:install
  #
  # @example Generated file location
  #   config/initializers/cmdx.rb
  #
  # @since 0.6.0
  class InstallGenerator < Rails::Generators::Base

    source_root File.expand_path("templates", __dir__)

    desc "Creates CMDx initializer with global configuration settings"

    ##
    # Copies the CMDx configuration template to the Rails initializers directory.
    #
    # Creates a new initializer file at `config/initializers/cmdx.rb` with
    # default configuration settings for:
    # - Task halt behaviors
    # - Timeout settings
    # - Batch execution controls
    # - Logger configuration
    #
    # @return [void]
    # @raise [Thor::Error] if the destination file cannot be created
    #
    # @example Generated initializer content
    #   CMDx.configure do |config|
    #     config.task_halt = CMDx::Result::FAILED
    #     config.task_timeout = nil
    #     # ... additional settings
    #   end
    def copy_initializer_file
      copy_file("install.rb", "config/initializers/cmdx.rb")
    end

  end
end
