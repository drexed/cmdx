# frozen_string_literal: true

module CMDx

  # Configuration class that manages global settings for CMDx including middlewares,
  # callbacks, coercions, validators, breakpoints, backtraces, and logging.
  class Configuration

    DEFAULT_BREAKPOINTS = %w[failed].freeze

    attr_accessor :middlewares, :callbacks, :coercions, :validators,
                  :task_breakpoints, :workflow_breakpoints, :logger,
                  :backtrace, :backtrace_cleaner, :exception_handler

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
    def initialize
      @middlewares = MiddlewareRegistry.new
      @callbacks = CallbackRegistry.new
      @coercions = CoercionRegistry.new
      @validators = ValidatorRegistry.new

      @task_breakpoints = DEFAULT_BREAKPOINTS
      @workflow_breakpoints = DEFAULT_BREAKPOINTS

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
    def to_h
      {
        middlewares: @middlewares,
        callbacks: @callbacks,
        coercions: @coercions,
        validators: @validators,
        task_breakpoints: @task_breakpoints,
        workflow_breakpoints: @workflow_breakpoints,
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
  def reset_configuration!
    @configuration = Configuration.new
  end

end
