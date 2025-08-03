# frozen_string_literal: true

module CMDx

  class Configuration

    DEFAULT_HALT = "failed"

    attr_accessor :logger, :middlewares, :callbacks, :coercions,
                  :validators, :task_halts, :workflow_halts

    # TODO: Change logger to a registry setup to allow loggers, statsd, etc.
    # https://www.prateekcodes.dev/rails-structured-event-reporting-system/#making-events-actually-useful-subscribers
    def initialize
      @logger = ::Logger.new($stdout) # TODO: ::Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)

      @middlewares = MiddlewareRegistry.new
      @callbacks = CallbackRegistry.new
      @coercions = CoercionRegistry.new
      @validators = ValidatorRegistry.new

      @task_halts = DEFAULT_HALT
      @workflow_halts = DEFAULT_HALT
    end

    def to_h
      {
        logger: @logger,
        middlewares: @middlewares,
        callbacks: @callbacks,
        coercions: @coercions,
        validators: @validators,
        task_halts: @task_halts,
        workflow_halts: @workflow_halts
      }
    end

  end

  extend self

  def configuration
    return @configuration if @configuration

    @configuration ||= Configuration.new
  end

  def configure
    raise ArgumentError, "block required" unless block_given?

    config = configuration
    yield(config)
    config
  end

  def reset_configuration!
    @configuration = Configuration.new
  end

end
