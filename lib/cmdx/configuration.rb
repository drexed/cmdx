# frozen_string_literal: true

module CMDx

  # Global defaults used by every task unless the task overrides via
  # `Task.settings`/register DSL. A fresh `Task` subclass inherits the current
  # configuration's registries (via `#dup`) at the time its accessor is first
  # called, so changes to configuration only apply to tasks that haven't
  # cached their copy yet.
  class Configuration

    attr_accessor :middlewares, :callbacks, :coercions, :validators, :executors,
      :mergers, :retriers, :deprecators, :telemetry, :correlation_id, :default_locale,
      :strict_context, :backtrace_cleaner, :log_exclusions, :log_formatter,
      :log_level, :logger

    def initialize
      @middlewares = Middlewares.new
      @callbacks   = Callbacks.new
      @coercions   = Coercions.new
      @validators  = Validators.new
      @executors   = Executors.new
      @mergers     = Mergers.new
      @retriers    = Retriers.new
      @deprecators = Deprecators.new
      @telemetry   = Telemetry.new

      @correlation_id    = nil
      @default_locale    = "en"
      @strict_context    = false
      @backtrace_cleaner = nil
      @log_exclusions    = EMPTY_ARRAY
      @log_formatter     = nil
      @log_level         = nil

      @logger = Logger.new(
        $stdout,
        progname: "cmdx",
        formatter: LogFormatters::Line.new,
        level: Logger::INFO
      )
    end

  end

  extend self

  # @return [Configuration] the lazily-initialized global configuration
  def configuration
    return @configuration if @configuration

    @configuration ||= Configuration.new
  end
  alias config configuration

  # Yields the global configuration for mutation.
  #
  # @yield [Configuration]
  # @return [Configuration]
  # @raise [ArgumentError] when no block is given
  def configure(&)
    raise ArgumentError, "CMDx.configure requires a block" unless block_given?

    configuration.tap(&)
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
    Task.instance_variable_set(:@retriers, nil)
    Task.instance_variable_set(:@deprecators, nil)
    Task.instance_variable_set(:@telemetry, nil)
  end

end
