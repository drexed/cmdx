# frozen_string_literal: true

module CMDx
  # Declarative retry configuration resolved from definition / config.
  class RetryPolicy

    # @return [Integer]
    attr_reader :max_attempts

    # @return [Array<Class>]
    attr_reader :retry_on

    # @return [Numeric, Proc, nil]
    attr_reader :jitter

    # @param max_attempts [Integer]
    # @param retry_on [Array<Class>]
    # @param jitter [Numeric, Proc, nil]
    def initialize(max_attempts:, retry_on: [], jitter: nil)
      @max_attempts = Integer(max_attempts)
      @retry_on = retry_on.freeze
      @jitter = jitter
      freeze
    end

    # @param exception [Exception]
    # @return [Boolean]
    def retry_exception?(exception)
      return false if @retry_on.empty?

      @retry_on.any? { |klass| exception.is_a?(klass) }
    end

    # @param session [Session]
    # @return [Numeric] seconds to sleep (may be 0)
    def wait_seconds(session)
      base = 0.0
      j = @jitter
      case j
      when Numeric then base + j.to_f
      when Proc then session.handler.instance_exec(&j).to_f
      else 0.0
      end
    end

  end
end
