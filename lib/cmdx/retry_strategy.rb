# frozen_string_literal: true

module CMDx
  # Encapsulates retry logic with configurable delay and jitter.
  class RetryStrategy

    # @return [Integer] maximum retries
    # @rbs @max_retries: Integer
    attr_reader :max_retries

    # @return [Numeric] base delay between retries in seconds
    # @rbs @delay: Numeric
    attr_reader :delay

    # @return [Numeric] max random jitter to add
    # @rbs @jitter: Numeric
    attr_reader :jitter

    # @return [Array<Class>] exception classes eligible for retry
    # @rbs @retry_on: Array[Class]
    attr_reader :retry_on

    # @param settings [Settings] task settings
    #
    # @rbs (Settings settings) -> void
    def initialize(settings)
      @max_retries = settings.resolved_retry_count
      @delay = settings.resolved_retry_delay
      @jitter = settings.resolved_retry_jitter
      @retry_on = settings.resolved_retry_on
    end

    # @return [Boolean] true if retries are configured
    #
    # @rbs () -> bool
    def retryable?
      max_retries.positive?
    end

    # Whether the exception is eligible for retry and attempts remain.
    #
    # @param exception [Exception] the exception to check
    # @param attempt [Integer] current attempt count
    #
    # @return [Boolean]
    #
    # @rbs (Exception exception, Integer attempt) -> bool
    def should_retry?(exception, attempt)
      retryable? &&
        attempt < max_retries &&
        retry_on.any? { |klass| exception.is_a?(klass) }
    end

    # Sleeps for the configured delay plus random jitter.
    #
    # @rbs () -> void
    def wait
      return unless delay.positive? || jitter.positive?

      sleep(delay + rand(0.0..jitter.to_f))
    end

  end
end
