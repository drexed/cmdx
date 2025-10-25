# frozen_string_literal: true

module CMDx

  # Configuration class that manages global settings for CMDx including middlewares,
  # callbacks, coercions, validators, breakpoints, backtraces, and logging.
  class Configuration

    # @rbs DEFAULT_BREAKPOINTS: Array[String]
    DEFAULT_BREAKPOINTS = %w[failed].freeze

    # @rbs DEFAULT_ROLLPOINTS: Array[String]
    DEFAULT_ROLLPOINTS = %w[failed].freeze

    # Returns the middleware registry for task execution.
    #
    # @return [MiddlewareRegistry] The middleware registry
    #
    # @example
    #   config.middlewares.register(CustomMiddleware)
    #
    # @rbs @middlewares: MiddlewareRegistry
    attr_accessor :middlewares

    # Returns the callback registry for task lifecycle hooks.
    #
    # @return [CallbackRegistry] The callback registry
    #
    # @example
    #   config.callbacks.register(:before_execution, :log_start)
    #
    # @rbs @callbacks: CallbackRegistry
    attr_accessor :callbacks

    # Returns the coercion registry for type conversions.
    #
    # @return [CoercionRegistry] The coercion registry
    #
    # @example
    #   config.coercions.register(:custom, CustomCoercion)
    #
    # @rbs @coercions: CoercionRegistry
    attr_accessor :coercions

    # Returns the validator registry for attribute validation.
    #
    # @return [ValidatorRegistry] The validator registry
    #
    # @example
    #   config.validators.register(:email, EmailValidator)
    #
    # @rbs @validators: ValidatorRegistry
    attr_accessor :validators

    # Returns the breakpoint statuses for task execution interruption.
    #
    # @return [Array<String>] Array of status names that trigger breakpoints
    #
    # @example
    #   config.task_breakpoints = ["failed", "skipped"]
    #
    # @rbs @task_breakpoints: Array[String]
    attr_accessor :task_breakpoints

    # Returns the breakpoint statuses for workflow execution interruption.
    #
    # @return [Array<String>] Array of status names that trigger breakpoints
    #
    # @example
    #   config.workflow_breakpoints = ["failed", "skipped"]
    #
    # @rbs @task_breakpoints: Array[String]
    # @rbs @workflow_breakpoints: Array[String]
    attr_accessor :workflow_breakpoints

    # Returns the logger instance for CMDx operations.
    #
    # @return [Logger] The logger instance
    #
    # @example
    #   config.logger.level = Logger::DEBUG
    #
    # @rbs @logger: Logger
    attr_accessor :logger

    # Returns whether to log backtraces for failed tasks.
    #
    # @return [Boolean] true if backtraces should be logged
    #
    # @example
    #   config.backtrace = true
    #
    # @rbs @backtrace: bool
    attr_accessor :backtrace

    # Returns the proc used to clean backtraces before logging.
    #
    # @return [Proc, nil] The backtrace cleaner proc, or nil if not set
    #
    # @example
    #   config.backtrace_cleaner = ->(bt) { bt.first(5) }
    #
    # @rbs @backtrace_cleaner: (Proc | nil)
    attr_accessor :backtrace_cleaner

    # Returns the proc called when exceptions occur during execution.
    #
    # @return [Proc, nil] The exception handler proc, or nil if not set
    #
    # @example
    #   config.exception_handler = ->(task, error) { Sentry.capture_exception(error) }
    #
    # @rbs @exception_handler: (Proc | nil)
    attr_accessor :exception_handler

    # Returns the statuses that trigger a task execution rollback.
    #
    # @return [Array<String>] Array of status names that trigger rollback
    #
    # @example
    #   config.rollback_on = ["failed", "skipped"]
    #
    # @rbs @rollback_on: Array[String]
    attr_accessor :rollback_on

    # Initializes a new Configuration instance with default values.
    #
    # Creates new registry instances for middlewares, callbacks, coercions, and
    # validators. Sets default breakpoints and configures a basic logger.
    #
    # @return [Configuration] a new Configuration instance
    #
    # @example
    #   config = Configuration.new
    #   config.middlewares.class # => MiddlewareRegistry
    #   config.task_breakpoints # => ["failed"]
    #
    # @rbs () -> void
    def initialize
      @middlewares = MiddlewareRegistry.new
      @callbacks = CallbackRegistry.new
      @coercions = CoercionRegistry.new
      @validators = ValidatorRegistry.new

      @task_breakpoints = DEFAULT_BREAKPOINTS
      @workflow_breakpoints = DEFAULT_BREAKPOINTS
      @rollback_on = DEFAULT_ROLLPOINTS

      @backtrace = false
      @backtrace_cleaner = nil
      @exception_handler = nil

      @logger = Logger.new(
        $stdout,
        progname: "cmdx",
        formatter: LogFormatters::Line.new,
        level: Logger::INFO
      )
    end

    # Converts the configuration to a hash representation.
    #
    # @return [Hash<Symbol, Object>] hash containing all configuration values
    #
    # @example
    #   config = Configuration.new
    #   config.to_h
    #   # => { middlewares: #<MiddlewareRegistry>, callbacks: #<CallbackRegistry>, ... }
    #
    # @rbs () -> Hash[Symbol, untyped]
    def to_h
      {
        middlewares: @middlewares,
        callbacks: @callbacks,
        coercions: @coercions,
        validators: @validators,
        task_breakpoints: @task_breakpoints,
        workflow_breakpoints: @workflow_breakpoints,
        rollback_on: @rollback_on,
        backtrace: @backtrace,
        backtrace_cleaner: @backtrace_cleaner,
        exception_handler: @exception_handler,
        logger: @logger
      }
    end

  end

  extend self

  # Returns the global configuration instance, creating it if it doesn't exist.
  #
  # @return [Configuration] the global configuration instance
  #
  # @example
  #   config = CMDx.configuration
  #   config.middlewares # => #<MiddlewareRegistry>
  #
  # @rbs () -> Configuration
  def configuration
    return @configuration if @configuration

    @configuration ||= Configuration.new
  end

  # Configures CMDx using a block that receives the configuration instance.
  #
  # @param block [Proc] the configuration block
  #
  # @yield [Configuration] the configuration instance to configure
  #
  # @return [Configuration] the configured configuration instance
  #
  # @raise [ArgumentError] when no block is provided
  #
  # @example
  #   CMDx.configure do |config|
  #     config.task_breakpoints = ["failed", "skipped"]
  #     config.logger.level = Logger::DEBUG
  #   end
  #
  # @rbs () { (Configuration) -> void } -> Configuration
  def configure
    raise ArgumentError, "block required" unless block_given?

    config = configuration
    yield(config)
    config
  end

  # Resets the global configuration to a new instance with default values.
  #
  # @return [Configuration] the new configuration instance
  #
  # @example
  #   CMDx.reset_configuration!
  #   # Configuration is now reset to defaults
  #
  # @rbs () -> Configuration
  def reset_configuration!
    @configuration = Configuration.new
  end

end
