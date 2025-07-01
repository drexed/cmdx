# frozen_string_literal: true

module CMDx

  ##
  # Provides global configuration management for CMDx framework settings.
  # The configuration system allows customization of default behaviors for tasks,
  # batches, logging, and error handling across the entire application.
  #
  # Configuration settings are stored as instance variables with explicit accessors
  # and can be modified through the configure block pattern. These settings serve
  # as defaults that can be overridden at the task or batch level when needed.
  #
  # ## Available Configuration Options
  #
  # - **logger**: Logger instance for task execution logging
  # - **task_halt**: Result statuses that cause `call!` to raise faults
  # - **batch_halt**: Result statuses that halt batch execution
  # - **middlewares**: Global middleware registry applied to all tasks
  # - **hooks**: Global hook registry applied to all tasks
  #
  # ## Configuration Hierarchy
  #
  # CMDx follows a configuration hierarchy where settings can be overridden:
  # 1. **Global Configuration**: Framework-wide defaults (this module)
  # 2. **Task Settings**: Class-level overrides via `task_settings!`
  # 3. **Runtime Parameters**: Instance-specific overrides during execution
  #
  # @example Basic configuration setup
  #   CMDx.configure do |config|
  #     config.logger = Logger.new($stdout)
  #     config.task_halt = ["failed"] # Only halt on failures
  #     config.middlewares.use CMDx::Middlewares::Timeout, 30
  #   end
  #
  # @example Rails initializer configuration
  #   # config/initializers/cmdx.rb
  #   CMDx.configure do |config|
  #     config.logger = Logger.new($stdout)
  #     config.task_halt = CMDx::Result::FAILED
  #     config.batch_halt = [CMDx::Result::FAILED, CMDx::Result::SKIPPED]
  #
  #     # Add global middlewares
  #     config.middlewares.use CMDx::Middlewares::Timeout, 30
  #     config.middlewares.use AuthenticationMiddleware if Rails.env.production?
  #
  #     # Add global hooks
  #     config.hooks.register :before_execution, :log_task_start
  #     config.hooks.register :on_success, NotificationHook.new([:slack])
  #     config.hooks.register :on_failure, :alert_admin, if: :production?
  #   end
  #
  # @example Custom logger configuration
  #   CMDx.configure do |config|
  #     config.logger = Logger.new(
  #       Rails.root.join('log', 'cmdx.log'),
  #       formatter: CMDx::LogFormatters::Json.new
  #     )
  #   end
  #
  # @example Environment-specific configuration
  #   CMDx.configure do |config|
  #     case Rails.env
  #     when 'development'
  #       config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::PrettyLine.new)
  #     when 'test'
  #       config.logger = Logger.new('/dev/null')  # Silent logging
  #     when 'production'
  #       config.logger = Logger.new($stdout, formatter: CMDx::LogFormatters::Json.new)
  #     end
  #   end
  #
  # @see Task Task-level configuration overrides
  # @see Batch Batch-level configuration overrides
  # @see LogFormatters Available logging formatters
  # @see Result Result statuses for halt configuration
  # @since 1.0.0

  ##
  # Configuration class that manages CMDx framework settings.
  # Provides explicit attribute accessors for all configuration options.
  #
  # @since 1.0.0
  class Configuration

    # Default configuration values
    DEFAULT_HALT = "failed"

    # Configuration attributes
    attr_accessor :logger, :middlewares, :hooks, :task_halt, :batch_halt

    ##
    # Initializes a new configuration with default values.
    #
    # @example
    #   config = CMDx::Configuration.new
    def initialize
      @logger      = ::Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
      @middlewares = MiddlewareRegistry.new
      @hooks       = HookRegistry.new
      @task_halt   = DEFAULT_HALT
      @batch_halt  = DEFAULT_HALT
    end

    ##
    # Returns a hash representation of the configuration.
    # Used internally by the framework for configuration merging.
    #
    # @return [Hash] configuration attributes as a hash
    # @example
    #   config = CMDx.configuration
    #   config.to_h  #=> { logger: ..., task_halt: "failed", ... }
    def to_h
      {
        logger: @logger,
        middlewares: @middlewares,
        hooks: @hooks,
        task_halt: @task_halt,
        batch_halt: @batch_halt
      }
    end

  end

  module_function

  ##
  # Returns the current global configuration instance.
  # Creates a new configuration with default values if none exists.
  #
  # The configuration is stored as a module-level variable and persists
  # throughout the application lifecycle. It uses lazy initialization,
  # creating the configuration only when first accessed.
  #
  # @return [Configuration] the current configuration object
  #
  # @example Accessing configuration values
  #   CMDx.configuration.logger          #=> <Logger instance>
  #   CMDx.configuration.task_halt       #=> "failed"
  #
  # @example Checking configuration state
  #   config = CMDx.configuration
  #   config.logger.class                #=> Logger
  def configuration
    return @configuration if @configuration

    @configuration ||= Configuration.new
  end

  ##
  # Configures CMDx settings using a block-based DSL.
  # This is the preferred method for setting up CMDx configuration
  # as it provides a clean, readable syntax for configuration management.
  #
  # The configuration block yields the current configuration object,
  # allowing you to set multiple options in a single, organized block.
  #
  # @yieldparam config [Configuration] the configuration object to modify
  # @return [Configuration] the updated configuration object
  # @raise [ArgumentError] if no block is provided
  #
  # @example Basic configuration
  #   CMDx.configure do |config|
  #     config.task_halt = ["failed", "skipped"]
  #   end
  #
  # @example Complex configuration with conditionals
  #   CMDx.configure do |config|
  #     config.logger = Rails.logger if defined?(Rails)
  #
  #     config.task_halt = if Rails.env.production?
  #       "failed"  # Only halt on failures in production
  #     else
  #       ["failed", "skipped"]  # Halt on both in development
  #     end
  #

  #   end
  #
  # @example Formatter configuration
  #   CMDx.configure do |config|
  #     config.logger = Logger.new($stdout).tap do |logger|
  #       logger.formatter = case ENV['LOG_FORMAT']
  #       when 'json'
  #         CMDx::LogFormatters::Json.new
  #       when 'pretty'
  #         CMDx::LogFormatters::PrettyLine.new
  #       else
  #         CMDx::LogFormatters::Line.new
  #       end
  #     end
  #   end
  def configure
    raise ArgumentError, "block required" unless block_given?

    config = configuration
    yield(config)
    config
  end

  ##
  # Resets the configuration to default values.
  # This method creates a fresh configuration object with framework defaults,
  # discarding any previously set custom values.
  #
  # @return [Configuration] the newly created configuration with default values
  #
  # @example Resetting configuration
  #   # After custom configuration
  #   CMDx.configure { |c| c.task_halt = ["failed"] }
  #   CMDx.configuration.task_halt  #=> ["failed"]
  #
  #   # Reset to defaults
  #   CMDx.reset_configuration!
  #   CMDx.configuration.task_halt  #=> "failed"
  #
  # @example Testing with clean configuration
  #   # In test setup
  #   def setup
  #     CMDx.reset_configuration!  # Start with clean defaults
  #   end
  #
  # @example Conditional reset
  #   # Reset configuration in development for experimentation
  #   CMDx.reset_configuration! if Rails.env.development?
  #
  # @note This method is primarily useful for testing or when you need
  #   to return to a known default state.
  def reset_configuration!
    @configuration = Configuration.new
  end

end
