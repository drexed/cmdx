# frozen_string_literal: true

module CMDx
  # Declared via {Task.circuit_breaker}. After inputs resolve, consults shared
  # store counters before the `retry_on` loop; opens after repeated failures
  # and short-circuits until `cool_off` elapses.
  #
  # Store keys are `namespace:TaskName` or `namespace:TaskName:segment`, with
  # `:failures` and `:open` suffix segments (see {StoreKey.compose}).
  class CircuitBreaker

    OPEN      = "open"
    FAILURES  = "failures"
    CLASS_KEY = :class

    class << self

      # @return [CircuitBreaker] disabled configuration
      def disabled
        DISABLED
      end

    end

    attr_reader :key

    # @param key [Symbol, String, Proc, #call, nil] `:class` (default when
    #   enabling via options only), context `Symbol`, static `String`, or
    #   callable; `nil` disables the breaker
    # @param options [Hash{Symbol => Object}]
    # @option options [Integer] :threshold (5) failures before the circuit opens
    # @option options [Integer] :cool_off (30) seconds the circuit stays open
    # @option options [Integer] :window (60) sliding window for the failure counter
    # @option options [String] :namespace ("cmdx:cb") first segment of store keys
    # @option options [Symbol] :on_open (:fail) `:fail` or `:skip` when open
    # @option options [Array<Class>] :on (`[StandardError]`) exception classes that
    #   increment the failure counter
    # @option options [Symbol, Proc, #call] :if gate `(task)` before checking
    # @option options [Symbol, Proc, #call] :unless gate `(task)` before checking
    def initialize(key, options = EMPTY_HASH)
      @key     = key
      @options = options.freeze
    end

    # @return [String]
    def namespace
      @options[:namespace] || "cmdx:cb"
    end

    # @return [Integer]
    def threshold
      @options[:threshold] || 5
    end

    # @return [Integer]
    def cool_off
      @options[:cool_off] || 30
    end

    # @return [Integer]
    def window
      @options[:window] || 60
    end

    # @return [Array<Class>]
    def on_exceptions
      @options.fetch(:on) { [StandardError] }.flatten
    end

    # @return [Symbol] `:fail` or `:skip`
    def on_open
      @options[:on_open] || :fail
    end

    # @return [Symbol, Proc, #call, nil]
    def condition_if
      @options[:if]
    end

    # @return [Symbol, Proc, #call, nil]
    def condition_unless
      @options[:unless]
    end

    # @return [Boolean]
    def enabled?
      !key.nil?
    end

    # Returns a new CircuitBreaker layering `new_options` onto the current one.
    # When `new_key` is non-nil it replaces the resolver; when `new_key` is
    # `nil` and only options change, the existing resolver is kept. When the
    # breaker was disabled and only options are passed, the resolver becomes
    # `:class`.
    #
    # @param new_key [Symbol, String, Proc, #call, nil]
    # @param new_options [Hash{Symbol => Object}]
    # @return [CircuitBreaker]
    def build(new_key, new_options)
      return self if new_key.nil? && new_options.empty?

      merged_key =
        if new_key.nil?
          enabled? || new_options.empty? ? @key : CLASS_KEY
        else
          new_key
        end
      merged_options = @options.merge(new_options)

      self.class.new(merged_key, merged_options)
    end

    # Runs the given block when the circuit is closed (or inactive). Records
    # failures for configured exception classes and clears the failure counter
    # after a successful run.
    #
    # @param task [Task]
    # @yield invoked when the circuit is closed or the breaker is inactive
    # @yieldreturn [Object] return value from the wrapped work
    # @return [Object] the block's return value
    # @note When the circuit is open, signals `fail!` or `skip!` on `task` —
    #   control does not return to the caller of {#process}.
    # @raise [ArgumentError] when `on_open` is not `:fail` or `:skip`
    def process(task)
      return yield unless enabled?
      return yield unless Util.satisfied?(condition_if, condition_unless, task)

      base = store_base(task)
      return yield if base.nil?

      open_key     = StoreKey.compose(base, OPEN)
      failures_key = StoreKey.compose(base, FAILURES)
      open!(task, open_key) if circuit_open?(open_key)

      begin
        yield
      rescue StandardError => e
        record_failure(e, failures_key, open_key, task)
        raise e
      else
        clear_failures(failures_key, task)
      end
    end

    private

    def store_base(task)
      segment = StoreKey.segment(task, key, skip: CLASS_KEY)

      if segment.nil?
        return StoreKey.compose(namespace, task.class.name) if key == CLASS_KEY

        return nil
      end

      StoreKey.compose(namespace, task.class.name, segment)
    end

    def circuit_open?(open_key)
      Stores.get(open_key)
    rescue StandardError
      false
    end

    def record_failure(exception, failures_key, open_key, task)
      return unless counts_as_failure?(exception)

      trip_open(failures_key, open_key, task)
    rescue StandardError
      nil
    end

    def clear_failures(failures_key, task)
      cleared = Stores.del(failures_key)
      Telemetry.emit_for(task, :circuit_failures_cleared, failures_key:) if cleared
    rescue StandardError
      nil
    end

    def counts_as_failure?(exception)
      list = on_exceptions
      return false if list.empty?

      list.any? { |klass| exception.is_a?(klass) }
    end

    def trip_open(failures_key, open_key, task)
      count = Stores.incr(failures_key, ttl: window)
      return unless count >= threshold

      Stores.set(open_key, OPEN, ttl: cool_off)
      Stores.del(failures_key)

      Telemetry.emit_for(
        task,
        :circuit_tripped,
        circuit_breaker_key: open_key,
        failures_key:,
        failure_count: count,
        threshold:,
        cool_off:
      )
    end

    def open!(task, open_key)
      message = "circuit open"
      metadata = {
        code: :circuit_open,
        circuit_breaker_key: open_key
      }

      remaining = Stores.remaining_ttl(open_key)
      metadata[:retry_after] = remaining if remaining

      Telemetry.emit_for(task, :circuit_open, **metadata, on_open:)

      case on_open
      when :fail
        task.fail!(message, **metadata)
      when :skip
        task.skip!(message, **metadata)
      else
        raise ArgumentError, <<~MSG.chomp
          circuit_breaker on_open must be :fail or :skip (got #{on_open.inspect}).
          See https://drexed.github.io/cmdx/circuit_breaker/
        MSG
      end
    end

    DISABLED = new(nil).freeze
    private_constant :DISABLED

  end
end
