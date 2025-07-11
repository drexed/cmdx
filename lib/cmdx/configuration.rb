# frozen_string_literal: true

module CMDx

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

    def initialize
      @logger        = ::Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
      @middlewares   = MiddlewareRegistry.new
      @callbacks     = CallbackRegistry.new
      @coercions     = CoercionRegistry.new
      @validators    = ValidatorRegistry.new
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
