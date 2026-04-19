# frozen_string_literal: true

module CMDx
  # Configurable retry-on-exception wrapper around a task's `work`. Supports
  # exception list, attempt `:limit`, base `:delay`, `:max_delay` cap, and
  # `:jitter` strategy (symbol, proc, or a configured block). Declared via
  # `Task.retry_on` and accumulates across inheritance.
  class Retry

    attr_reader :exceptions

    # @param exceptions [Array<Class>] exceptions to retry on
    # @param options [Hash{Symbol => Object}]
    # @option options [Integer] :limit (3) maximum retry attempts
    # @option options [Float] :delay (0.5) base delay in seconds between attempts
    # @option options [Float] :max_delay clamp for computed delays
    # @option options [Symbol, Proc, #call] :jitter built-in strategy (`:exponential`,
    #   `:half_random`, `:full_random`, `:bounded_random`) or custom
    # @yield [attempt, delay] optional custom jitter block, used when `:jitter` isn't set
    def initialize(exceptions, options = EMPTY_HASH, &block)
      @exceptions = exceptions.flatten
      @options    = options.freeze
      @block      = block
    end

    # Returns a new Retry layering `new_exceptions` and `new_options` onto the
    # current one. Used for inheritance so subclasses extend rather than
    # replace.
    #
    # @param new_exceptions [Array<Class>]
    # @param new_options [Hash{Symbol => Object}]
    # @yield [attempt, delay] optional replacement jitter block
    # @return [Retry]
    def build(new_exceptions, new_options, &block)
      return self if new_exceptions.empty?

      merged_exceptions = exceptions | new_exceptions.flatten
      merged_options    = @options.merge(new_options)

      self.class.new(merged_exceptions, merged_options, &block || @block)
    end

    # @return [Integer]
    def limit
      @options[:limit] || 3
    end

    # @return [Float] base delay in seconds
    def delay
      @options[:delay] || 0.5
    end

    # @return [Float, nil] upper bound for computed delays
    def max_delay
      @options[:max_delay]
    end

    # @return [Symbol, Proc, #call, nil] jitter strategy or the block given to {#initialize}
    def jitter
      @options[:jitter] || @block
    end

    # Sleeps `attempt`'s jittered/bounded delay. No-op when the base delay is zero.
    #
    # @param attempt [Integer] zero-based retry attempt number
    # @param task [Task, nil] used as receiver for Symbol/Proc jitter strategies
    # @return [void]
    def wait(attempt, task = nil)
      return unless delay.positive?

      d =
        case jitter
        when :exponential
          delay * (2**attempt)
        when :half_random
          (delay / 2.0) + (rand * delay / 2.0)
        when :full_random
          rand * delay
        when :bounded_random
          delay + (rand * delay)
        when Symbol
          task.send(jitter, attempt, delay)
        when Proc
          task.instance_exec(attempt, delay, &jitter)
        else
          if jitter.respond_to?(:call)
            jitter.call(attempt, delay)
          else
            delay
          end
        end

      d = d.clamp(0, max_delay) if max_delay
      Kernel.sleep(d) if d.positive?
    end

    # Executes the block up to `limit + 1` times. Re-raises the last
    # exception when attempts are exhausted.
    #
    # @param task [Task, nil] passed to {#wait} so jitter strategies can use it
    # @yieldparam attempt [Integer] zero-based attempt index
    # @yieldreturn [Object] the block's successful return value
    # @return [Object] the block's successful return value
    # @raise [Exception] the last caught exception once retries exhaust
    def process(task = nil, &)
      return yield(0) if exceptions.empty? || !limit.positive?

      (limit + 1).times do |attempt|
        return yield(attempt)
      rescue *exceptions => e
        raise(e) if attempt >= limit

        wait(attempt, task)
      end
    end

  end
end
