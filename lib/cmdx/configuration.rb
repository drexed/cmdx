# frozen_string_literal: true

module CMDx

  class Configuration

    DEFAULT_HALT = "failed"

    attr_accessor :logger, :middlewares, :callbacks, :coercions,
                  :validators, :task_halt, :workflow_halt

    def initialize
      @logger        = ::Logger.new($stdout) # TODO: ::Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
      @middlewares   = Middlewares::Registry.new
      @callbacks     = Callbacks::Registry.new
      @coercions     = Coercions::Registry.new
      @validators    = Validators::Registry.new
      @task_halt     = DEFAULT_HALT
      @workflow_halt = DEFAULT_HALT
    end

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
