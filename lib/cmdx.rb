# frozen_string_literal: true

require "bigdecimal"
require "date"
require "i18n"
require "json"
require "logger"
require "pp"
require "securerandom"
require "time"
require "timeout"
require "zeitwerk"

module CMDx; end

# Set up Zeitwerk loader for the CMDx gem
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cmdx" => "CMDx")
# loader.ignore("#{__dir__}/cmdx/core_ext")
loader.ignore("#{__dir__}/cmdx/configuration")
loader.ignore("#{__dir__}/cmdx/exceptions")
# loader.ignore("#{__dir__}/cmdx/faults")
# loader.ignore("#{__dir__}/cmdx/railtie")
# loader.ignore("#{__dir__}/cmdx/rspec")
# loader.ignore("#{__dir__}/generators")
# loader.ignore("#{__dir__}/locales")
loader.setup

# Pre-load core extensions to avoid circular dependencies
# require_relative "cmdx/core_ext/module"
# require_relative "cmdx/core_ext/object"
# require_relative "cmdx/core_ext/hash"

# Pre-load configuration to make module methods available
# This is acceptable since configuration is fundamental to the framework
require_relative "cmdx/configuration"

# Pre-load exceptions to make them available at the top level
# This ensures CMDx::Error and its descendants are always available
require_relative "cmdx/exceptions"

# Pre-load fault classes to make them available at the top level
# This ensures CMDx::Failed and CMDx::Skipped are always available
# require_relative "cmdx/faults"

# Conditionally load Rails components if Rails is available
# if defined?(Rails::Generators)
#   require_relative "generators/cmdx/install_generator"
#   require_relative "generators/cmdx/task_generator"
#   require_relative "generators/cmdx/workflow_generator"
# end

# Load the Railtie last after everything else is required so we don't
# need to load any CMDx components when we use this Railtie.
# require_relative "cmdx/railtie" if defined?(Rails::Railtie)
