# frozen_string_literal: true

require "bigdecimal"
require "date"
require "forwardable"
require "json"
require "logger"
require "pathname"
require "securerandom"
require "set"
require "time"
require "timeout"
require "yaml"
require "zeitwerk"

module CMDx

  # @rbs EMPTY_ARRAY: Array[untyped]
  EMPTY_ARRAY = [].freeze
  private_constant :EMPTY_ARRAY

  # @rbs EMPTY_HASH: Hash[untyped, untyped]
  EMPTY_HASH = {}.freeze
  private_constant :EMPTY_HASH

  # @rbs EMPTY_STRING: String
  EMPTY_STRING = ""
  private_constant :EMPTY_STRING

  # @return [Pathname]
  #
  # @rbs () -> Pathname
  def self.gem_path
    @gem_path ||= Pathname.new(__dir__).parent
  end

  # @return [Configuration]
  #
  # @rbs () -> Configuration
  def self.configuration
    @configuration ||= Configuration.new
  end

  # @rbs () { (Configuration) -> void } -> void
  def self.configure
    yield configuration
  end

  # @rbs () -> void
  def self.reset_configuration!
    @configuration = Configuration.new
  end

end

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cmdx" => "CMDx", "json" => "JSON")
loader.ignore("#{__dir__}/cmdx/configuration")
loader.ignore("#{__dir__}/cmdx/exception")
loader.ignore("#{__dir__}/cmdx/fault")
loader.ignore("#{__dir__}/cmdx/railtie")
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/locales")
loader.setup

require_relative "cmdx/configuration"
require_relative "cmdx/exception"
require_relative "cmdx/fault"

if defined?(Rails::Generators)
  require_relative "generators/cmdx/install_generator"
  require_relative "generators/cmdx/task_generator"
  require_relative "generators/cmdx/workflow_generator"
end

require_relative "cmdx/railtie" if defined?(Rails::Railtie)
