# frozen_string_literal: true

module CMDx
  # Declared via {Task.rate_limit}. After inputs resolve, consults a shared
  # limiter once per execution (retries do not consume additional quota) and
  # short-circuits before the circuit breaker when the bucket is full.
  #
  # Store keys are `namespace:TaskName` or `namespace:TaskName:segment` (see
  # {StoreKey.compose}).
  class RateLimit

    # Result of a limiter strategy deciding whether an execution may proceed.
    Admission = Data.define(:admitted, :count, :level, :retry_after, :limiter) do
      # @return [Boolean]
      def admitted?
        admitted
      end
    end

    # Quota snapshot passed to built-in and custom limiter strategies.
    Quota = Data.define(:task, :store_key, :max, :per, :cost, :limiter, :options)

    CLASS_KEY = :class

    class << self

      # @return [RateLimit] disabled configuration (no key)
      def disabled
        DISABLED
      end

    end

    attr_reader :key

    # @param key [Symbol, String, Proc, #call, nil] `:class`, context `Symbol`,
    #   static `String`, or callable; `nil` disables rate limiting
    # @param options [Hash{Symbol => Object}]
    # @option options [Integer] :max maximum admissions per window or bucket capacity
    # @option options [Integer] :per window length in seconds (`:fixed_window`) or
    #   seconds to leak one unit (`:leaky_bucket`)
    # @option options [Symbol, #call] :limiter (`:fixed_window`, `:leaky_bucket`, or custom)
    # @option options [Numeric] :cost (1) units charged per admitted execution
    # @option options [String] :namespace ("cmdx:rl") first segment of store keys
    # @option options [Symbol] :on_limit (:fail) `:fail` or `:skip` when over limit
    # @option options [Symbol, Proc, #call] :if gate `(task)` before checking
    # @option options [Symbol, Proc, #call] :unless gate `(task)` before checking
    def initialize(key, options = EMPTY_HASH)
      @key     = key
      @options = options.freeze
    end

    # @return [String]
    def namespace
      @options[:namespace] || "cmdx:rl"
    end

    # @return [Integer, nil]
    def max
      @options[:max]
    end

    # @return [Integer, nil]
    def per
      @options[:per]
    end

    # @return [Symbol]
    def limiter
      @options[:limiter] || :fixed_window
    end

    # @return [Numeric]
    def cost
      raw = @options[:cost]
      return 1 if raw.nil?

      Float(raw)
    end

    # @return [Symbol] `:fail` or `:skip`
    def on_limit
      @options[:on_limit] || :fail
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

    # Returns a new RateLimit layering `new_options` onto the current one.
    #
    # @param new_key [Symbol, String, Proc, #call, nil]
    # @param new_options [Hash{Symbol => Object}]
    # @return [RateLimit]
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

    # Runs the limiter once, then yields when admitted or inactive.
    #
    # @param task [Task]
    # @yield invoked when admitted or rate limiting is inactive
    # @yieldreturn [Object] return value from the wrapped work
    # @return [Object] the block's return value
    # @note When over limit, signals `skip!` or `fail!` on `task` — control does
    #   not return to the caller of {#process}.
    # @raise [ArgumentError] when `max` / `per` are missing or invalid, or
    #   `on_limit` is not `:fail` or `:skip`
    def process(task)
      return yield unless enabled?
      return yield unless Util.satisfied?(condition_if, condition_unless, task)

      store_key = store_base(task)
      return yield if store_key.nil?

      quota = Quota.new(
        task:,
        store_key:,
        max: Integer(max),
        per: Integer(per),
        cost:,
        limiter:,
        options: @options
      )

      admission = invoke_limiter(task, quota)
      if admission.admitted?
        admitted!(task, store_key, admission, quota)
        yield
      else
        exceeded!(task, store_key, admission, quota)
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

    def invoke_limiter(task, quota)
      callable =
        if limiter.is_a?(Proc)
          ->(q) { task.instance_exec(q, &limiter) }
        else
          limiters_registry(task).resolve(limiter)
        end

      callable.call(quota)
    end

    def limiters_registry(task)
      if task.class.respond_to?(:limiters)
        task.class.limiters
      else
        CMDx.configuration.limiters
      end
    end

    def admitted!(task, store_key, admission, quota)
      payload = admission_payload(store_key, admission, quota)

      Telemetry.emit(task, :rate_limit_admitted, **payload)
    end

    def exceeded!(task, store_key, admission, quota)
      message  = exceeded_message(admission, quota)
      metadata = admission_payload(store_key, admission, quota).merge(code: :rate_limited)

      Telemetry.emit(task, :rate_limit_exceeded, **metadata, on_limit:)

      case on_limit
      when :fail
        task.fail!(message, **metadata)
      when :skip
        task.skip!(message, **metadata)
      else
        raise ArgumentError, <<~MSG.chomp
          rate_limit on_limit must be :fail or :skip (got #{on_limit.inspect}).
          See https://drexed.github.io/cmdx/rate_limit/
        MSG
      end
    end

    def exceeded_message(admission, quota)
      parts = ["rate limited"]
      parts << "#{admission.count}/#{quota.max}" if admission.count
      parts << "level=#{admission.level}" if admission.level
      parts << "per #{quota.per}s"
      parts << "(#{quota.limiter})"
      parts.join(" ")
    end

    def admission_payload(store_key, admission, quota)
      {
        rate_limit_key: store_key,
        limiter: admission.limiter,
        max: quota.max,
        per: quota.per,
        count: admission.count,
        level: admission.level,
        retry_after: admission.retry_after
      }.compact
    end

    DISABLED = new(nil).freeze
    private_constant :DISABLED

  end
end
