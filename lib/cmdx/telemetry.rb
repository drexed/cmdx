# frozen_string_literal: true

module CMDx
  # Pub/sub for runtime lifecycle and infrastructure events (see {EVENTS}).
  # Subscribers are callables receiving an {Event} data object. {emit_for}
  # dispatches only when subscribers are registered so telemetry has zero cost
  # when unused.
  class Telemetry

    # Immutable event payload passed to subscribers.
    Event = Data.define(:xid, :cid, :root, :type, :task, :tid, :name, :payload, :timestamp) do
      def self.build(task, name, root: false, payload: EMPTY_HASH)
        new(
          xid: Chain.current.xid,
          cid: Chain.current.id,
          root:,
          type: task.class.type,
          task: task.class,
          tid: task.tid,
          name:,
          payload:,
          timestamp: Time.now.utc
        )
      end
    end

    # Lifecycle and infrastructure event names the runtime and store-backed
    # helpers emit.
    EVENTS = %i[
      task_started
      task_deprecated
      task_retried
      task_rolled_back
      task_executed
      lock_acquired
      lock_busy
      idempotency_claimed
      idempotency_completed
      idempotency_duplicate
      circuit_open
      circuit_tripped
      circuit_reset
    ].freeze

    class << self

      # Dispatches `payload` when `task`'s telemetry registry has subscribers
      # for `name`. No-op when nothing is subscribed.
      #
      # @param task [Task]
      # @param name [Symbol] one of {EVENTS}
      # @param root [Boolean] whether this task started the active chain
      # @param payload [Hash{Symbol => Object}] extra fields merged into the event payload
      # @return [void]
      def emit_for(task, name, root: false, **payload)
        telemetry = task.class.telemetry
        return unless telemetry.subscribed?(name)

        event = Event.build(task, name, root:, payload:)
        telemetry.emit(name, event)
      end

    end

    attr_reader :registry

    def initialize
      @registry = {}
    end

    # @param source [Telemetry] registry to duplicate
    # @return [void]
    def initialize_copy(source)
      @registry = source.registry.transform_values(&:dup)
    end

    # Registers a subscriber for `event`.
    #
    # @param event [Symbol] one of {EVENTS}
    # @param callable [#call, nil] subscriber callable; pass either this or a block
    # @param block [#call, nil] subscriber when `callable` is omitted
    # @yieldparam evt [Event]
    # @return [Telemetry] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are provided, when
    #   the subscriber isn't callable, or when `event` is unknown
    def subscribe(event, callable = nil, &block)
      subscriber = callable || block

      if callable && block
        raise ArgumentError, "subscriber: provide either a callable or a block, not both"
      elsif !subscriber.respond_to?(:call)
        raise ArgumentError, <<~MSG.chomp
          subscriber must respond to #call (got #{subscriber.class}).
          See https://drexed.github.io/cmdx/configuration/#telemetry
        MSG
      elsif !EVENTS.include?(event)
        raise ArgumentError, <<~MSG.chomp
          unknown telemetry event #{event.inspect}, must be one of #{EVENTS.inspect}.
          See https://drexed.github.io/cmdx/configuration/#telemetry
        MSG
      end

      (registry[event] ||= []) << subscriber
      self
    end

    # Removes a previously registered subscriber. Drops the event entry
    # entirely when no subscribers remain.
    #
    # @param event [Symbol] one of {EVENTS}
    # @param callable [#call] the subscriber to remove
    # @return [Telemetry] self for chaining
    # @raise [UnknownEntryError] when `event` is unknown
    def unsubscribe(event, callable)
      unless EVENTS.include?(event)
        raise UnknownEntryError, <<~MSG.chomp
          unknown telemetry event #{event.inspect}, must be one of #{EVENTS.inspect}.
          See https://drexed.github.io/cmdx/configuration/#telemetry
        MSG
      end

      if (subscribers = registry[event])
        subscribers.delete(callable)
        registry.delete(event) if subscribers.empty?
      end

      self
    end

    # @param event [Symbol]
    # @return [Boolean] true when at least one subscriber exists for `event`
    def subscribed?(event)
      registry.key?(event)
    end

    # @param event [Symbol]
    # @return [#call]
    # @raise [UnknownEntryError] when `event` isn't registered
    def lookup(event)
      registry[event] || begin
        raise UnknownEntryError, <<~MSG.chomp
          unknown telemetry event #{event.inspect}; registered: #{registry.keys.inspect}.
          See https://drexed.github.io/cmdx/configuration/#telemetry
        MSG
      end
    end

    # @return [Boolean]
    def empty?
      registry.empty?
    end

    # @return [Integer] number of subscribed events
    def size
      registry.size
    end

    # @return [Integer] total subscribers across all events
    def count
      registry.each_value.sum(&:size)
    end

    # Dispatches `payload` to every subscriber of `event`. No-op when there
    # are no subscribers.
    #
    # @param event [Symbol]
    # @param payload [Event]
    # @return [void]
    def emit(event, payload)
      return if empty?

      subscribers = lookup(event)
      return if subscribers.nil? || subscribers.empty?

      subscribers.each { |callable| callable.call(payload) }
    end

  end
end
