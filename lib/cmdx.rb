# frozen_string_literal: true

require "bigdecimal"
require "date"
require "json"
require "logger"
require "securerandom"
require "time"
require "yaml"

module CMDx

  # Frozen empty array reused as a sentinel return value to avoid per-call
  # allocations on hot paths.
  #
  # @api private
  EMPTY_ARRAY = [].freeze
  private_constant :EMPTY_ARRAY

  # Frozen empty hash reused as a sentinel return value to avoid per-call
  # allocations on hot paths.
  #
  # @api private
  EMPTY_HASH = {}.freeze
  private_constant :EMPTY_HASH

  # Shared empty string constant used as a sentinel default. Intentionally
  # not frozen so callers may treat it as a mutable seed when needed.
  #
  # @api private
  EMPTY_STRING = ""
  private_constant :EMPTY_STRING

  # Root exception type for the library. Every CMDx-raised exception inherits
  # from this class, so `rescue CMDx::Error` (or its alias `CMDx::Exception`)
  # catches anything thrown by the framework without trapping unrelated
  # `StandardError` descendants. {Fault} is the notable subclass propagated
  # by `execute!`.
  Error = Exception = Class.new(StandardError)

  # Raised when a task or workflow attempts to define an input where an
  # accessor with the same name already exists.
  DefinitionError = Class.new(Error)

  # Raised by {Deprecation} when a task configured with
  # `settings(deprecate: :error)` is executed. Signals that the caller must
  # migrate off the deprecated task before continuing.
  DeprecationError = Class.new(Error)

  # Raised when a subclass fails to fulfill an abstract contract — most
  # commonly when {Task} is invoked without overriding `#work`, or when a
  # {Workflow} attempts to define `#work` itself.
  ImplementationError = Class.new(Error)

  # Raised by the middleware chain when a registered middleware fails to
  # yield to `next_link`, which would otherwise silently skip the task body.
  MiddlewareError = Class.new(Error)

end

require_relative "cmdx/version"
require_relative "cmdx/fault"
require_relative "cmdx/util"
require_relative "cmdx/i18n_proxy"
require_relative "cmdx/logger_proxy"
require_relative "cmdx/log_formatters/json"
require_relative "cmdx/log_formatters/key_value"
require_relative "cmdx/log_formatters/line"
require_relative "cmdx/log_formatters/logstash"
require_relative "cmdx/log_formatters/raw"
require_relative "cmdx/coercions/array"
require_relative "cmdx/coercions/big_decimal"
require_relative "cmdx/coercions/boolean"
require_relative "cmdx/coercions/complex"
require_relative "cmdx/coercions/date"
require_relative "cmdx/coercions/date_time"
require_relative "cmdx/coercions/float"
require_relative "cmdx/coercions/hash"
require_relative "cmdx/coercions/integer"
require_relative "cmdx/coercions/rational"
require_relative "cmdx/coercions/string"
require_relative "cmdx/coercions/symbol"
require_relative "cmdx/coercions/time"
require_relative "cmdx/coercions/coerce"
require_relative "cmdx/coercions"
require_relative "cmdx/validators/absence"
require_relative "cmdx/validators/exclusion"
require_relative "cmdx/validators/format"
require_relative "cmdx/validators/inclusion"
require_relative "cmdx/validators/length"
require_relative "cmdx/validators/numeric"
require_relative "cmdx/validators/presence"
require_relative "cmdx/validators/validate"
require_relative "cmdx/validators"
require_relative "cmdx/input"
require_relative "cmdx/inputs"
require_relative "cmdx/output"
require_relative "cmdx/outputs"
require_relative "cmdx/callbacks"
require_relative "cmdx/middlewares"
require_relative "cmdx/telemetry"
require_relative "cmdx/settings"
require_relative "cmdx/retry"
require_relative "cmdx/deprecation"
require_relative "cmdx/context"
require_relative "cmdx/chain"
require_relative "cmdx/signal"
require_relative "cmdx/result"
require_relative "cmdx/pipeline"
require_relative "cmdx/runtime"
require_relative "cmdx/errors"
require_relative "cmdx/task"
require_relative "cmdx/workflow"
require_relative "cmdx/configuration"

# Conditionally load Rails components if Rails is available
if defined?(Rails::Generators)
  require_relative "generators/cmdx/install_generator"
  require_relative "generators/cmdx/task_generator"
  require_relative "generators/cmdx/workflow_generator"
end

# Load the Railtie last after everything else is required so
# we don't load any CMDx components when we use this Railtie.
require_relative "cmdx/railtie" if defined?(Rails::Railtie)
