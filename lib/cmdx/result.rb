# frozen_string_literal: true

module CMDx
  # Frozen outcome of a task execution. Provides read-only access to the
  # task's signal (state/status/reason/metadata/cause), the chain it belongs
  # to, its context, and lifecycle metadata (retries, duration, rollback,
  # deprecated). Constructed by Runtime at the end of `execute`.
  #
  # @see Runtime#finalize_result
  # @see Signal
  class Result

    EVENTS = Set[
      *Signal::STATES,
      *Signal::STATUSES,
      :ok,
      :ko
    ].map!(&:to_sym).freeze
    private_constant :EVENTS

    attr_reader :chain

    # @param chain [Chain] the chain this result belongs to
    # @param task [Task] the executed task instance
    # @param signal [Signal] the final signal from the task's lifecycle
    # @param options [Hash{Symbol => Object}] frozen execution metadata
    # @option options [String] :tid
    # @option options [Boolean] :strict
    # @option options [Boolean] :deprecated
    # @option options [Boolean] :rolled_back
    # @option options [Integer] :retries
    # @option options [Float] :duration milliseconds
    def initialize(chain, task, signal, **options)
      @chain   = chain
      @task    = task
      @signal  = signal
      @options = options.freeze
    end

    # @return [String] uuid_v7 identifier for this execution
    def tid
      @options[:tid]
    end

    # @return [Class<Task>] the task class that ran
    def task
      @task.class
    end

    # @return [String] `"Task"` or `"Workflow"`
    def type
      task.type
    end

    # @return [String, nil] correlation id or the global configuration's correlation id
    def xid
      chain.xid
    end

    # @return [String] uuid_v7 identifier for the chain this result belongs to
    def cid
      chain.id
    end

    # @return [Integer, nil] this result's position in the chain
    def index
      @chain.index(self)
    end

    # @return [Boolean] true when this result is the root of the chain
    def root?
      !!@options[:root]
    end

    # @return [Context] frozen after the root task's teardown
    def context
      @task.context
    end
    alias ctx context

    # @return [Errors] frozen by Runtime teardown
    def errors
      @task.errors
    end

    # @return [String] one of {Signal::STATES}
    def state
      @signal.state
    end

    # @return [Boolean]
    def complete?
      @signal.complete?
    end

    # @return [Boolean]
    def interrupted?
      @signal.interrupted?
    end

    # @return [String] one of {Signal::STATUSES}
    def status
      @signal.status
    end

    # @return [Boolean]
    def success?
      @signal.success?
    end

    # @return [Boolean]
    def skipped?
      @signal.skipped?
    end

    # @return [Boolean]
    def failed?
      @signal.failed?
    end

    # @return [Boolean]
    def ok?
      @signal.ok?
    end

    # @return [Boolean]
    def ko?
      @signal.ko?
    end

    # Dispatches the block when any of `keys` matches a truthy predicate on
    # this result. Returns `self` for chaining.
    #
    # @param keys [Array<Symbol, String>] any of the predicate bases:
    #   `complete`, `interrupted`, `success`, `skipped`, `failed`, `ok`, `ko`
    # @yieldparam result [Result] this result
    # @return [Result] self for chaining
    # @raise [ArgumentError] when no block is given or a key is unknown
    #
    # @example
    #   result
    #     .on(:success) { |r| deliver(r.context) }
    #     .on(:failed)  { |r| alert(r.reason) }
    def on(*keys)
      raise ArgumentError, "Result#on requires a block" unless block_given?

      yield(self) if keys.any? do |k|
        unless EVENTS.include?(k.to_sym)
          raise ArgumentError, <<~MSG.chomp
            unknown Result#on event #{k.inspect}, must be one of #{EVENTS.to_a.inspect}.
            See https://drexed.github.io/cmdx/outcomes/result/#predicate-dispatch-with-on
          MSG
        end

        public_send(:"#{k}?")
      end

      self
    end

    # @return [String, nil]
    def reason
      @signal.reason
    end

    # @return [Hash{Symbol => Object}] frozen empty hash when none provided
    def metadata
      @signal.metadata
    end

    # The upstream failed result this one was echoed from (via `Task#throw!`
    # or a rescued {Fault} inside `work`). `nil` when this is a locally
    # originated failure or the result didn't fail.
    #
    # @return [Result, nil]
    def origin
      @signal.origin
    end

    # @return [Exception, nil]
    def cause
      @signal.cause
    end

    # The originating failed result at the bottom of the propagation chain.
    # Walks `origin` recursively. `self` when this result is the originator;
    # `nil` when not failed.
    #
    # @return [Result, nil]
    def caused_failure
      return unless failed?

      @caused_failure ||= origin ? origin.caused_failure : self
    end

    # @return [Boolean] true when this result originated the failure chain
    def caused_failure?
      failed? && origin.nil?
    end

    # The nearest upstream failed result. `self` when this result is the
    # originator; `nil` when not failed.
    #
    # @return [Result, nil]
    def threw_failure
      return unless failed?

      origin || self
    end

    # @return [Boolean] true when this result re-threw an upstream failure
    def thrown_failure?
      failed? && !origin.nil?
    end

    # The backtrace captured by `fail!` / `throw!` for Fault propagation.
    # `nil` when this result is not a failure or the failure didn't capture
    # a backtrace.
    #
    # @return [Array<String>, nil]
    def backtrace
      @signal.backtrace
    end

    # @return [Integer]
    def retries
      @options[:retries] || 0
    end

    # @return [Boolean]
    def retried?
      retries.positive?
    end

    # @return [Boolean] true when produced via `execute!`
    def strict?
      !!@options[:strict]
    end

    # @return [Boolean] true when the task class is marked deprecated
    def deprecated?
      !!@options[:deprecated]
    end

    # @return [Boolean] true when a failing task's `rollback` ran
    def rolled_back?
      !!@options[:rolled_back]
    end

    # @return [Float, nil] lifecycle duration in milliseconds
    def duration
      @options[:duration]
    end

    # @return [Array<Symbol, String>]
    def tags
      task.settings.tags
    end

    # @return [Hash{Symbol => Object}] memoized serialization. Includes
    #   `:cause`, `:origin`, `:threw_failure`, `:caused_failure`, `:rolled_back`
    #   on failure.
    def to_h
      @to_h ||= {
        xid:,
        cid:,
        index:,
        root: root?,
        type:,
        task:,
        tid:,
        context:,
        state:,
        status:,
        reason:,
        metadata:,
        strict: strict?,
        deprecated: deprecated?,
        retried: retried?,
        retries:,
        duration:,
        tags:
      }.tap do |hash|
        if failed?
          hash[:cause] = cause
          hash[:origin] = hash_for_failure(:origin)
          hash[:threw_failure] = hash_for_failure(:threw_failure)
          hash[:caused_failure] = hash_for_failure(:caused_failure)
          hash[:rolled_back] = rolled_back?
        end
      end
    end

    # JSON-friendly hash view. Aliases the memoized {#to_h} for conventional
    # `as_json` callers (e.g. Rails).
    #
    # @return [Hash{Symbol => Object}]
    def as_json(*)
      to_h
    end

    # Serializes the result to a JSON string. Non-primitive entries (the
    # `:task` Class, `:cause` Exception) emit via their stdlib `to_json`
    # defaults; `:context` delegates to {Context#to_json}.
    #
    # @param args [Array] forwarded to `Hash#to_json`
    # @return [String]
    def to_json(*args)
      to_h.to_json(*args)
    end

    # @return [String] space-separated `key=value.inspect` pairs; failure
    #   references render as `<TaskClass uuid>`.
    def to_s
      @to_s ||= begin
        buf = String.new(capacity: 256)

        to_h.each_with_object(buf) do |(k, v), buf|
          buf << " " unless buf.empty?

          ks = k.name

          if v.nil?
            buf << ks << "=nil"
          elsif ks == "origin" || ks.end_with?("_failure")
            buf << ks << "=<" << v[:task].to_s << " " << v[:tid] << ">"
          else
            buf << ks << "=" << v.inspect
          end
        end
      end
    end

    # Pattern-matching support for `case result in {...}`.
    #
    # @param keys [Array<Symbol>, nil] restrict the returned hash to these keys
    # @return [Hash{Symbol => Object}]
    def deconstruct_keys(keys)
      keys.nil? ? to_h : to_h.slice(*keys)
    end

    # Pattern-matching support for `case result in [...]`.
    #
    # @return [Array<Array(Symbol, Object)>]
    def deconstruct
      to_h.to_a
    end

    private

    # @param key [Symbol] reader name such as `:caused_failure` or `:threw_failure`
    # @return [Hash{Symbol => Object}, nil] compact `{task:, tid:}` map for graph hints
    def hash_for_failure(key)
      r = public_send(key)
      return if r.nil?

      { task: r.task, tid: r.tid }
    end

  end
end
