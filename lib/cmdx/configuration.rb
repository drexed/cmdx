# frozen_string_literal: true

module CMDx
  # Global configuration for the CMDx framework.
  class Configuration

    # @rbs DEFAULT_BREAKPOINTS: Array[String]
    DEFAULT_BREAKPOINTS = %w[failed].freeze

    # @rbs DEFAULT_ROLLPOINTS: Array[String]
    DEFAULT_ROLLPOINTS = %w[failed].freeze

    # @return [Logger]
    attr_accessor :logger

    # @return [Symbol]
    attr_accessor :log_level

    # @return [Object, nil] formatter class for structured logging
    attr_accessor :log_formatter

    # @return [Array<String>] statuses that trigger Fault on execute!
    attr_accessor :task_breakpoints

    # @return [Array<String>] statuses that halt a workflow
    attr_accessor :workflow_breakpoints

    # @return [Array<String>] statuses that trigger rollback
    attr_accessor :rollback_on

    # @return [Boolean]
    attr_accessor :backtrace

    # @return [Proc, nil]
    attr_accessor :backtrace_cleaner

    # @return [Telemetry, nil]
    attr_accessor :telemetry

    # @return [Proc] id generator callable
    attr_accessor :id_generator

    # @return [Array<Array>] global middleware entries [[klass, opts], ...]
    attr_accessor :middlewares

    # @return [Hash{Symbol => Array}] global callback entries per phase
    attr_accessor :callbacks

    # @return [Hash{Symbol => Object}] global coercion overrides
    attr_accessor :coercions

    # @return [Hash{Symbol => Object}] global validator overrides
    attr_accessor :validators

    # @rbs () -> void
    def initialize
      reset!
    end

    # @rbs () -> void
    def reset!
      @logger = Logger.new($stdout, level: :info)
      @log_level = :info
      @log_formatter = nil
      @task_breakpoints = DEFAULT_BREAKPOINTS.dup
      @workflow_breakpoints = DEFAULT_BREAKPOINTS.dup
      @rollback_on = DEFAULT_ROLLPOINTS.dup
      @backtrace = false
      @backtrace_cleaner = nil
      @telemetry = nil
      @id_generator = -> { Identifier.generate }
      @middlewares = []
      @callbacks = {}
      @coercions = {}
      @validators = {}
    end

  end
end
