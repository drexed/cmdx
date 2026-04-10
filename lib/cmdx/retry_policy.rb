# frozen_string_literal: true

module CMDx
  # Retry configuration for task execution. Lives on Definition, consulted by Runtime.
  class RetryPolicy

    # @return [Integer]
    attr_reader :max_retries

    # @return [Array<Class>] exception classes to retry on
    attr_reader :retry_on

    # @return [Symbol] jitter strategy (:none, :equal, :full)
    attr_reader :jitter

    # @return [Numeric] base delay in seconds
    attr_reader :delay

    # @param max_retries [Integer]
    # @param retry_on [Array<Class>]
    # @param jitter [Symbol]
    # @param delay [Numeric]
    #
    # @rbs (?Integer max_retries, ?retry_on: Array[Class], ?jitter: Symbol, ?delay: Numeric) -> void
    def initialize(max_retries = 0, retry_on: [StandardError], jitter: :none, delay: 0)
      @max_retries = max_retries
      @retry_on = Array(retry_on)
      @jitter = jitter
      @delay = delay
    end

    # @param error [StandardError]
    # @return [Boolean]
    #
    # @rbs (StandardError error) -> bool
    def matches?(error)
      @retry_on.any? { |klass| error.is_a?(klass) }
    end

    # Sleeps for the configured delay with optional jitter.
    #
    # @param attempt [Integer]
    #
    # @rbs (Integer attempt) -> void
    def wait(attempt)
      return if @delay <= 0

      base = @delay * attempt
      actual = case @jitter
               when :equal then (base * 0.5) + (rand * base * 0.5)
               when :full then rand * base
               else base
               end

      sleep(actual)
    end

  end
end
