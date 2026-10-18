# frozen_string_literal: true

module CMDx
  # Declared via {Task.lock_with}. After inputs resolve, acquires a store lease
  # (`SET` with `nx: true`) and runs idempotency (when declared), the full
  # `retry_on` loop, and output verification inside that lease.
  #
  # Store keys are `namespace:TaskName:segment` (see {StoreKey.compose}). The
  # stored value is the holding task's `tid`. Release uses a conditional delete so
  # a late releaser cannot drop a newer holder's lease after TTL expiry.
  #
  # After a successful acquire, the lease is released in `ensure` for any exit from
  # the wrapped block (success, `skip!` / `fail!`, or uncaught error). The lease
  # is not released between in-process `retry_on` attempts.
  class Lock

    class << self

      # @return [Lock] disabled configuration (no key)
      def disabled
        DISABLED
      end

    end

    attr_reader :key

    # @param key [Symbol, String, Proc, #call, nil] segment resolved per task;
    #   `nil` disables locking. Symbols read from `context`; `Proc` / blocks are
    #   `instance_exec`'d on the task (with `task` as the first block argument,
    #   same as callbacks); other `#call`ables receive the task. Blank segments
    #   skip acquiring.
    # @param options [Hash{Symbol => Object}]
    # @option options [Integer] :ttl (300) lease expiry in seconds when the holder
    #   does not release; size for worst-case hold time including the retry loop
    # @option options [String] :namespace ("cmdx:lock") first segment of the store key
    # @option options [Numeric, false, nil] :wait (0) max seconds to wait for the
    #   lease; `0`, `nil`, or `false` try once
    # @option options [Symbol] :on_busy (:fail) `:skip` or `:fail` when the lease
    #   cannot be acquired within `:wait`
    # @option options [Symbol, Proc, #call] :if gate `(task)` for acquiring
    # @option options [Symbol, Proc, #call] :unless gate `(task)` for acquiring
    def initialize(key, options = EMPTY_HASH)
      @key     = key
      @options = options.freeze
    end

    # @return [String]
    def namespace
      @options[:namespace] || "cmdx:lock"
    end

    # @return [Integer]
    def ttl
      @options[:ttl] || 300
    end

    # @return [Float]
    def wait
      raw = @options[:wait]
      return 0.0 if raw.nil? || raw == false

      Float(raw)
    end

    # @return [Symbol] `:skip` or `:fail`
    def on_busy
      @options[:on_busy] || :fail
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

    # Returns a new Lock layering `new_options` onto the current one.
    #
    # @param new_key [Symbol, String, Proc, #call, nil]
    # @param new_options [Hash{Symbol => Object}]
    # @return [Lock]
    def build(new_key, new_options)
      return self if new_key.nil? && new_options.empty?

      merged_key     = new_key.nil? ? @key : new_key
      merged_options = @options.merge(new_options)

      self.class.new(merged_key, merged_options)
    end

    # Runs the given block behind a store lease when {#enabled?} and gates pass.
    #
    # @param task [Task]
    # @yield invoked when the lease is acquired or locking is inactive
    # @yieldreturn [Object] return value from the wrapped work
    # @return [Object] the block's return value
    # @note When the lease cannot be acquired, signals `skip!` or `fail!` on
    #   `task` — control does not return to the caller of {#process}. Busy
    #   metadata may include `:holder` and `:retry_after` when the backend
    #   exposes the current value and TTL.
    # @raise [ArgumentError] when `on_busy` is not `:skip` or `:fail`, or `wait`
    #   is negative
    def process(task)
      return yield unless enabled?
      return yield unless Util.satisfied?(condition_if, condition_unless, task)

      segment = StoreKey.segment(task, key)
      return yield if segment.nil?

      store_key = StoreKey.compose(namespace, task.class.name, segment)
      token = task.tid

      if acquire_lock(store_key, token)
        Telemetry.emit_for(task, :lock_acquired, lock_key: store_key)

        begin
          yield
        ensure
          release_lock(store_key, token)
        end
      else
        busy!(task, store_key)
      end
    end

    private

    def acquire_lock(store_key, token) # rubocop:disable Naming/PredicateMethod -- returns whether the lease was taken
      wait_seconds = wait
      raise ArgumentError, "lock_with wait must be >= 0 (got #{wait_seconds})" if wait_seconds.negative?

      deadline = (Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait_seconds if wait_seconds.positive?)

      loop do
        return true if Stores.set(store_key, token, nx: true, ttl:)
        return false unless deadline

        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep_interval = [0.05, deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)].min
        Kernel.sleep(sleep_interval) if sleep_interval.positive?
      end

      false
    end

    def release_lock(store_key, token)
      Stores.del_if(store_key, token)
    end

    def busy!(task, store_key)
      holder = Stores.get(store_key)
      retry_after = Stores.remaining_ttl(store_key)

      message = holder ? "lock held" : "lock not acquired"
      metadata = {
        code: :busy,
        lock_key: store_key,
        holder:,
        retry_after:
      }.compact

      Telemetry.emit_for(task, :lock_busy, **metadata, on_busy:)

      case on_busy
      when :fail
        task.fail!(message, **metadata)
      when :skip
        task.skip!(message, **metadata)
      else
        raise ArgumentError, <<~MSG.chomp
          lock_with on_busy must be :skip or :fail (got #{on_busy.inspect}).
          See https://drexed.github.io/cmdx/locks/
        MSG
      end
    end

    DISABLED = new(nil).freeze
    private_constant :DISABLED

  end
end
