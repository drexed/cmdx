# frozen_string_literal: true

module CMDx

  class Configuration

    DEFAULT_HALT = "failed"

    attr_accessor :logger, :callbacks, :coercions, :validators, :halt_task_on, :halt_workflow_on

    def initialize
      @logger = ::Logger.new($stdout) # TODO: ::Logger.new($stdout, formatter: CMDx::LogFormatters::Line.new)
      @callbacks = Callbacks::Registry.new
      @coercions = Coercions::Registry.new
      @validators = Validators::Registry.new
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

    def to_hash
      to_h.transform_values(&:dup)
    end

  end

  module_function

  def configuration
    return @_configuration if @_configuration

    @_configuration ||= Configuration.new
  end

  def configure
    raise ArgumentError, "block required" unless block_given?

    config = configuration
    yield(config)
    config
  end

  def reset_configuration!
    @_configuration = Configuration.new
  end

end
