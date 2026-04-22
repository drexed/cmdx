# frozen_string_literal: true

module CMDx

  # Global defaults used by every task unless the task overrides via
  # `Task.settings`/register DSL. A fresh `Task` subclass inherits the current
  # configuration's registries (via `#dup`) at the time its accessor is first
  # called, so changes to configuration only apply to tasks that haven't
  # cached their copy yet.
  class Configuration

    attr_accessor :middlewares, :callbacks, :coercions, :validators,
      :executors, :mergers, :telemetry, :default_locale, :strict_context,
      :backtrace_cleaner, :logger, :log_level, :log_formatter

    def initialize
      @middlewares = Middlewares.new
      @callbacks   = Callbacks.new
      @coercions   = Coercions.new
      @validators  = Validators.new
      @executors   = Executors.new
      @mergers     = Mergers.new
      @telemetry   = Telemetry.new

      @default_locale    = "en"
      @strict_context    = false
      @backtrace_cleaner = nil

      @log_formatter = LogFormatters::Line.new
      @log_level     = Logger::INFO
      @logger        = Logger.new(
        $stdout,
        progname: "cmdx",
        formatter: @log_formatter,
        level: @log_level
      )
    end

  end

  extend self

  # @return [Configuration] the lazily-initialized global configuration
  def configuration
    return @configuration if @configuration

    @configuration ||= Configuration.new
  end

  # Yields the global configuration for mutation.
  #
  # @yield [Configuration]
  # @return [Configuration]
  # @raise [ArgumentError] when no block is given
  def configure
    raise ArgumentError, "block required" unless block_given?

    config = configuration
    yield(config)
    config
  end

  # Replaces the global configuration with a fresh instance and invalidates
  # the cached registries on `Task` so new lookups rebuild from the new config.
  # Intended for test setup/teardown.
  #
  # @return [void]
  def reset_configuration!
    @configuration = Configuration.new
    return unless defined?(Task)

    Task.instance_variable_set(:@middlewares, nil)
    Task.instance_variable_set(:@callbacks, nil)
    Task.instance_variable_set(:@coercions, nil)
    Task.instance_variable_set(:@validators, nil)
    Task.instance_variable_set(:@executors, nil)
    Task.instance_variable_set(:@mergers, nil)
    Task.instance_variable_set(:@telemetry, nil)
  end

end
