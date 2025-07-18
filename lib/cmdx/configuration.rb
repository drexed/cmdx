# frozen_string_literal: true

module CMDx

  # Global configuration class for CMDx framework settings.
  # Manages logging, middleware, callbacks, coercions, validators, and halt conditions.
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

    # Initialize a new Configuration instance with default settings.
    #
    # @example
    #   config = CMDx::Configuration.new
    #   config.logger.level = Logger::DEBUG
    #
    # @return [Configuration] A new configuration instance
    def initialize
      @logger        = ::Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
      @middlewares   = MiddlewareRegistry.new
      @callbacks     = CallbackRegistry.new
      @coercions     = CoercionRegistry.new
      @validators    = ValidatorRegistry.new
      @task_halt     = DEFAULT_HALT
      @workflow_halt = DEFAULT_HALT
    end

    # Convert the configuration to a hash representation.
    #
    # @example
    #   config = CMDx::Configuration.new
    #   hash = config.to_h
    #   puts hash[:task_halt] #=> "failed"
    #
    # @return [Hash] Hash containing all configuration values
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

  # Get the current global configuration instance.
  # Creates a new configuration if none exists.
  #
  # @example
  #   config = CMDx.configuration
  #   config.logger.level = Logger::INFO
  #
  # @return [Configuration] The global configuration instance
  def configuration
    return @configuration if @configuration

    @configuration ||= Configuration.new
  end

  # Configure the global CMDx settings using a block.
  #
  # @example
  #   CMDx.configure do |config|
  #     config.task_halt = ["failed", "error"]
  #     config.logger.level = Logger::DEBUG
  #   end
  #
  # @yield [Configuration] The configuration instance
  #
  # @return [Configuration] The configured instance
  #
  # @raise [ArgumentError] If no block is provided
  def configure
    raise ArgumentError, "block required" unless block_given?

    config = configuration
    yield(config)
    config
  end

  # Reset the global configuration to default values.
  #
  # @example
  #   CMDx.reset_configuration!
  #   CMDx.configuration.task_halt #=> "failed"
  #
  # @return [Configuration] A new configuration instance with defaults
  def reset_configuration!
    @configuration = Configuration.new
  end

end
