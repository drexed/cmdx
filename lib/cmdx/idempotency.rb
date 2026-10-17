# frozen_string_literal: true

module CMDx
  # Declared via {Task.idempotent_by}. After inputs resolve, claims a shared
  # store slot and runs the `retry_on` loop inside that claim so duplicate
  # invocations with the same logical key short-circuit before `work` repeats.
  #
  # Store keys are `namespace:TaskName:segment` (see {StoreKey.compose}). Values
  # move `processing` → `completed` on success; the key is deleted on
  # `StandardError` so retries can reclaim.
  class Idempotency

    PROCESSING = "processing"
    COMPLETED  = "completed"

    class << self

      # @return [Idempotency] disabled configuration (no key)
      def disabled
        DISABLED
      end

    end

    attr_reader :key

    # @param key [Symbol, String, Proc, #call, nil] segment resolved per task;
    #   `nil` disables idempotency. Symbols read from `context`; `Proc` /
    #   blocks are `instance_exec`'d on the task (with `task` as the first
    #   block argument, same as callbacks); other `#call`ables receive the
    #   task. Blank segments skip claiming.
    # @param options [Hash{Symbol => Object}]
    # @option options [Integer] :ttl (300) expiry in seconds for store entries
    # @option options [String] :namespace ("cmdx:idem") first segment of the store key
    # @option options [Symbol] :on_duplicate (:skip) `:skip` or `:fail` when the
    #   slot is already claimed
    # @option options [Symbol, Proc, #call] :if gate `(task)` for claiming
    # @option options [Symbol, Proc, #call] :unless gate `(task)` for claiming
    def initialize(key, options = EMPTY_HASH)
      @key     = key
      @options = options.freeze
    end

    # @return [String]
    def namespace
      @options[:namespace] || "cmdx:idem"
    end

    # @return [Symbol] `:skip` or `:fail`
    def on_duplicate
      @options[:on_duplicate] || :skip
    end

    # @return [Integer]
    def ttl
      @options[:ttl] || 300
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

    # Returns a new Idempotency layering `new_options` onto the current one.
    # When `new_key` is non-nil it replaces the resolver; when `new_key` is
    # `nil` and only options change, the existing resolver is kept (option-only
    # updates such as `idempotent_by ttl: 600`).
    #
    # @param new_key [Symbol, String, Proc, #call, nil]
    # @param new_options [Hash{Symbol => Object}]
    # @return [Idempotency]
    def build(new_key, new_options)
      return self if new_key.nil? && new_options.empty?

      merged_key     = new_key.nil? ? @key : new_key
      merged_options = @options.merge(new_options)

      self.class.new(merged_key, merged_options)
    end

    # Runs the given block behind a store claim when {#enabled?} and gates pass.
    # Releases the claim on `StandardError` so `retry_on` can run `work` again;
    # marks the slot `completed` after the block returns successfully.
    #
    # @param task [Task]
    # @yield invoked when the claim succeeds or idempotency is inactive
    # @yieldreturn [Object] return value from the wrapped work (ignored by callers)
    # @return [Object] the block's return value
    # @note On duplicate keys, signals `skip!` or `fail!` on `task` — control
    #   does not return to the caller of {#process}.
    # @raise [ArgumentError] when `on_duplicate` is not `:skip` or `:fail`
    def process(task)
      return yield unless enabled?
      return yield unless Util.satisfied?(condition_if, condition_unless, task)

      segment = StoreKey.segment(task, key)
      return yield if segment.nil?

      store_key = StoreKey.compose(namespace, task.class.name, segment)

      if Stores.set(store_key, PROCESSING, nx: true, ttl:)
        begin
          yield
        rescue StandardError
          Stores.del(store_key)
          raise
        else
          Stores.set(store_key, COMPLETED, xx: true, ttl:)
        end
      else
        duplicate!(task, store_key)
      end
    end

    private

    def duplicate!(task, store_key)
      state    = Stores.get(store_key)
      message  = "duplicate request (state=#{state})"
      metadata = { code: :duplicate, idempotency_key: store_key }

      case on_duplicate
      when :fail
        task.fail!(message, **metadata)
      when :skip
        task.skip!(message, **metadata)
      else
        raise ArgumentError, <<~MSG.chomp
          idempotent_by on_duplicate must be :skip or :fail (got #{on_duplicate.inspect}).
          See https://drexed.github.io/cmdx/idempotency/
        MSG
      end
    end

    DISABLED = new(nil).freeze
    private_constant :DISABLED

  end
end
