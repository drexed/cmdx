# frozen_string_literal: true

require "bigdecimal"
require "logger"
require "securerandom"
require "set"
require "zeitwerk"

module CMDx

  # @rbs EMPTY_HASH: Hash[untyped, untyped]
  EMPTY_HASH = {}.freeze

  # @rbs EMPTY_ARRAY: Array[untyped]
  EMPTY_ARRAY = [].freeze

  # @rbs EMPTY_STRING: String
  EMPTY_STRING = ""

  class << self

    # Returns the global configuration instance.
    #
    # @return [Configuration]
    #
    # @rbs () -> Configuration
    def configuration
      @configuration ||= Configuration.new
    end

    # Yields the global configuration for modification.
    #
    # @yield [Configuration]
    #
    # @rbs () { (Configuration) -> void } -> Configuration
    def configure
      yield(configuration)
      configuration
    end

    # Resets the global configuration to defaults.
    #
    # @return [Configuration]
    #
    # @rbs () -> Configuration
    def reset_configuration!
      @configuration = Configuration.new
    end

  end

end

# Manually require files that Zeitwerk should not autoload
require_relative "cmdx/version"
require_relative "cmdx/exception"
require_relative "cmdx/fault"
require_relative "cmdx/configuration"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cmdx" => "CMDx")
loader.ignore("#{__dir__}/cmdx/version.rb")
loader.ignore("#{__dir__}/cmdx/exception.rb")
loader.ignore("#{__dir__}/cmdx/fault.rb")
loader.ignore("#{__dir__}/cmdx/configuration.rb")
loader.ignore("#{__dir__}/cmdx/railtie.rb")
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/locales")
loader.setup

require_relative "cmdx/railtie" if defined?(Rails::Railtie)
