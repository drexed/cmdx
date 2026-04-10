# frozen_string_literal: true

module CMDx
  # Per-task settings with lazy delegation to the parent class or global configuration.
  # Each setting defaults to nil (meaning "inherit from parent").
  class Settings

    # @rbs VALID_ON_FAILURE: Array[Symbol]
    VALID_ON_FAILURE = %i[raise skip none].freeze

    # @return [Settings, nil] parent settings for inheritance
    #
    # @rbs @parent: Settings?
    attr_reader :parent

    attr_accessor :logger, :log_level, :log_formatter, :tags, :on_failure, :retry_count, :retry_delay, :retry_jitter, :retry_on, :deprecate

    # @param parent [Settings, nil] parent settings for lazy delegation
    #
    # @rbs (?Settings? parent) -> void
    def initialize(parent = nil)
      @parent = parent
    end

    # @return [Logger] resolved logger
    #
    # @rbs () -> Logger
    def resolved_logger
      logger || parent&.resolved_logger || CMDx.configuration.logger
    end

    # @return [Symbol, nil] resolved log level
    #
    # @rbs () -> Symbol?
    def resolved_log_level
      log_level || parent&.resolved_log_level || CMDx.configuration.log_level
    end

    # @return [Proc, nil] resolved log formatter
    #
    # @rbs () -> Proc?
    def resolved_log_formatter
      log_formatter || parent&.resolved_log_formatter || CMDx.configuration.log_formatter
    end

    # @return [Array<Symbol>] resolved tags
    #
    # @rbs () -> Array[Symbol]
    def resolved_tags
      tags || parent&.resolved_tags || EMPTY_ARRAY
    end

    # @return [Symbol] resolved on_failure behavior
    #
    # @rbs () -> Symbol
    def resolved_on_failure
      on_failure || parent&.resolved_on_failure || :raise
    end

    # @return [Integer] resolved retry count
    #
    # @rbs () -> Integer
    def resolved_retry_count
      retry_count || parent&.resolved_retry_count || 0
    end

    # @return [Numeric] resolved retry delay in seconds
    #
    # @rbs () -> Numeric
    def resolved_retry_delay
      retry_delay || parent&.resolved_retry_delay || 0
    end

    # @return [Numeric] resolved jitter max
    #
    # @rbs () -> Numeric
    def resolved_retry_jitter
      retry_jitter || parent&.resolved_retry_jitter || 0
    end

    # @return [Array<Class>] exception classes to retry on
    #
    # @rbs () -> Array[Class]
    def resolved_retry_on
      retry_on || parent&.resolved_retry_on || [StandardError]
    end

    # @return [Hash, nil] resolved deprecation config
    #
    # @rbs () -> Hash[Symbol, untyped]?
    def resolved_deprecate
      deprecate || parent&.resolved_deprecate
    end

    # @return [Boolean] whether retries are configured
    #
    # @rbs () -> bool
    def retryable?
      resolved_retry_count.positive?
    end

    # @return [Boolean] whether the task is deprecated
    #
    # @rbs () -> bool
    def deprecated?
      !resolved_deprecate.nil?
    end

    # Duplicates settings for a child class.
    #
    # @return [Settings] a new Settings with self as parent
    #
    # @rbs () -> Settings
    def for_child
      self.class.new(self)
    end

  end
end
