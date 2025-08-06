# frozen_string_literal: true

module CMDx

  class Configuration

    DEFAULT_BREAKPOINTS = %w[failed].freeze

    attr_accessor :middlewares, :callbacks, :coercions, :validators,
                  :task_breakpoints, :workflow_breakpoints, :logger

    def initialize
      @middlewares = MiddlewareRegistry.new
      @callbacks = CallbackRegistry.new
      @coercions = CoercionRegistry.new
      @validators = ValidatorRegistry.new

      @task_breakpoints = DEFAULT_BREAKPOINTS
      @workflow_breakpoints = DEFAULT_BREAKPOINTS

      @logger = Logger.new(
        $stdout,
        progname: "cmdx",
        formatter: LogFormatters::Line.new,
        level: Logger::INFO
      )
    end

    def to_h
      {
        middlewares: @middlewares,
        callbacks: @callbacks,
        coercions: @coercions,
        validators: @validators,
        task_breakpoints: @task_breakpoints,
        workflow_breakpoints: @workflow_breakpoints,
        logger: @logger
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
