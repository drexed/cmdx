# frozen_string_literal: true

module CMDx

  # Global configuration class for CMDx framework settings.
  #
  # Manages logging, middleware, callbacks, coercions, validators, and halt conditions
  # for the entire CMDx framework. The Configuration class provides centralized control
  # over framework behavior including task execution flow, error handling, and component
  # registration. All settings configured here become defaults for tasks and workflows
  # unless explicitly overridden at the task or workflow level.
  #
  # The configuration system supports both global and per-task customization, allowing
  # fine-grained control over framework behavior while maintaining sensible defaults.
  class Configuration

    DEFAULT_HALT = "failed"

    # @return [Logger] Logger instance for task execution logging
    attr_accessor :logger

    # @return [MiddlewareRegistry] Global middleware registry applied to all tasks
    attr_accessor :middlewares

    # @return [CallbackRegistry] Global callback registry applied to all tasks
    attr_accessor :callbacks

    # @return [CoercionRegistry] Global coercion registry for custom parameter types
    attr_accessor :coercions

    # @return [ValidatorRegistry] Global validator registry for custom parameter validation
    attr_accessor :validators

    # @return [String, Array<String>] Result statuses that cause `call!` to raise faults
    attr_accessor :task_halt

    # @return [String, Array<String>] Result statuses that halt workflow execution
    attr_accessor :workflow_halt

    # Creates a new configuration instance with default settings.
    #
    # Initializes all configuration attributes with sensible defaults including
    # a stdout logger with line formatting, empty registries for extensibility
    # components, and default halt conditions for both tasks and workflows.
    #
    # @return [Configuration] a new configuration instance with default settings
    #
    # @example Create a new configuration
    #   config = Configuration.new
    #   config.logger.class #=> Logger
    #   config.task_halt #=> "failed"
    def initialize
      @logger        = ::Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
      @middlewares   = MiddlewareRegistry.new
      @callbacks     = CallbackRegistry.new
      @coercions     = CoercionRegistry.new
      @validators    = ValidatorRegistry.new
      @task_halt     = DEFAULT_HALT
      @workflow_halt = DEFAULT_HALT
    end

    # Converts the configuration to a hash representation.
    #
    # Creates a hash containing all configuration attributes for serialization,
    # inspection, or transfer between processes. The hash includes all registries
    # and settings in their current state.
    #
    # @return [Hash] hash representation of the configuration
    # @option return [Logger] :logger the configured logger instance
    # @option return [MiddlewareRegistry] :middlewares the middleware registry
    # @option return [CallbackRegistry] :callbacks the callback registry
    # @option return [CoercionRegistry] :coercions the coercion registry
    # @option return [ValidatorRegistry] :validators the validator registry
    # @option return [String, Array<String>] :task_halt the task halt configuration
    # @option return [String, Array<String>] :workflow_halt the workflow halt configuration
    #
    # @example Convert configuration to hash
    #   config = Configuration.new
    #   hash = config.to_h
    #   hash[:logger].class #=> Logger
    #   hash[:task_halt] #=> "failed"
    def to_h
      {
        logger: @logger,
        middlewares: @middlewares,
        callbacks: @callbacks,
        coercions: @coercions,
        validators: @validators,
        task_halt: @task_halt,
        workflow_halt: @workflow_halt
      }
    end

  end

  module_function

  # Returns the current global configuration instance.
  #
  # Provides access to the singleton configuration instance used by the entire
  # CMDx framework. Creates a new configuration with default settings if none
  # exists. This method is thread-safe and ensures only one configuration
  # instance exists per process.
  #
  # @return [Configuration] the current global configuration instance
  #
  # @example Access global configuration
  #   config = CMDx.configuration
  #   config.logger.level = Logger::DEBUG
  #   config.task_halt = ["failed", "skipped"]
  def configuration
    return @configuration if @configuration

    @configuration ||= Configuration.new
  end

  # Configures the global CMDx settings using a block.
  #
  # Yields the current configuration instance to the provided block for
  # modification. This is the recommended way to configure CMDx as it
  # provides a clean DSL-like interface for setting up the framework.
  #
  # @param block [Proc] configuration block that receives the configuration instance
  #
  # @return [Configuration] the configured configuration instance
  #
  # @raise [ArgumentError] if no block is provided
  #
  # @example Configure CMDx settings
  #   CMDx.configure do |config|
  #     config.logger.level = Logger::INFO
  #     config.task_halt = ["failed", "skipped"]
  #     config.middlewares.register(CMDx::Middlewares::Timeout.new(seconds: 30))
  #   end
  #
  # @example Configure with custom logger
  #   CMDx.configure do |config|
  #     config.logger = Rails.logger
  #     config.logger.formatter = CMDx::LogFormatters::JSON.new
  #   end
  def configure
    raise ArgumentError, "block required" unless block_given?

    config = configuration
    yield(config)
    config
  end

  # Resets the global configuration to default settings.
  #
  # Creates a new configuration instance with default settings, discarding
  # any existing configuration. This is useful for testing scenarios or
  # when you need to start with a clean configuration state.
  #
  # @return [Configuration] a new configuration instance with default settings
  #
  # @example Reset to defaults
  #   CMDx.configure { |c| c.task_halt = ["failed", "skipped"] }
  #   CMDx.configuration.task_halt #=> ["failed", "skipped"]
  #
  #   CMDx.reset_configuration!
  #   CMDx.configuration.task_halt #=> "failed"
  #
  # @example Use in test setup
  #   RSpec.configure do |config|
  #     config.before(:each) { CMDx.reset_configuration! }
  #   end
  def reset_configuration!
    @configuration = Configuration.new
  end

end
