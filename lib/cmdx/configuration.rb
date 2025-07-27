# frozen_string_literal: true

module CMDx

  class Configuration

    DEFAULT_HALT = "failed"

    attr_accessor :logger, :callbacks, :coercions, :validators, :halt_task_on, :halt_workflow_on

    def initialize
      @logger = ::Logger.new($stdout) # TODO: ::Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
      @callbacks = CallbackRegistry.new
      @coercions = CoercionRegistry.new
      @validators = ValidatorRegistry.new
      @halt_task_on = DEFAULT_HALT
      @halt_workflow_on = DEFAULT_HALT
    end

    def to_h
      {
        logger: @logger,
        callbacks: @callbacks,
        coercions: @coercions,
        validators: @validators,
        halt_task_on: @halt_task_on,
        halt_workflow_on: @halt_workflow_on
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
