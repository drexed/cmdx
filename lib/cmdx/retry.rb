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
    # @param block [#call, nil] optional jitter callable used when `:jitter` isn't set
    # @option options [Integer] :limit (3) maximum retry attempts
    # @option options [Float] :delay (0.5) base delay in seconds between attempts
    # @option options [Float] :max_delay clamp for computed delays
    # @option options [Symbol, Proc, #call] :jitter built-in strategy (`:exponential`,
    #   `:half_random`, `:full_random`, `:bounded_random`, `:linear`, `:fibonacci`,
    #   `:decorrelated_jitter`) or custom
    # @yieldparam attempt [Integer]
    # @yieldparam delay [Float]
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
    # @param block [#call, nil] replacement jitter callable (falls back to the prior block)
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
    # @param prev_delay [Float, nil] previous computed delay; only consumed by
    #   `:decorrelated_jitter` to thread state across attempts
    # @return [Float, nil] the computed (and possibly clamped) delay, or `nil` when
    #   `delay` is zero
    def wait(attempt, task = nil, prev_delay = nil)
      return unless delay.positive?

      d =
        case jitter
        when NilClass
          delay
        when Symbol
          registry = retriers_registry(task)

          if registry.key?(jitter)
            registry.lookup(jitter).call(attempt, delay, prev_delay)
          else
            task.send(jitter, attempt, delay)
          end
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
      d
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

      prev_delay = nil
      (limit + 1).times do |attempt|
        return yield(attempt)
      rescue *exceptions => e
        raise(e) if attempt >= limit
        raise(e) unless Util.satisfied?(@options[:if], @options[:unless], task, e, attempt)

        prev_delay = wait(attempt, task, prev_delay)
      end
    end

    private

    # Resolves the retriers registry to consult for built-in jitter strategies.
    # Prefers the task class's registry (so per-task `register(:retrier, ...)`
    # overrides take effect) and falls back to the global configuration when
    # no task is supplied.
    #
    # @param task [Task, nil]
    # @return [Retriers]
    def retriers_registry(task)
      if task && task.class.respond_to?(:retriers)
        task.class.retriers
      else
        CMDx.configuration.retriers
      end
    end

  end
end
