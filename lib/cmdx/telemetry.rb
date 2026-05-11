# frozen_string_literal: true

module CMDx
  # Pub/sub for runtime lifecycle events (see {EVENTS}). Subscribers are
  # callables receiving an {Event} data object. Runtime emits events only when
  # subscribers are registered so telemetry has zero cost when unused.
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

    # Lifecycle event names Runtime emits.
    EVENTS = %i[
      task_started
      task_deprecated
      task_retried
      task_rolled_back
      task_executed
    ].freeze

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
        raise ArgumentError,
          "subscriber must respond to #call (got #{subscriber.class}). " \
          "See https://drexed.github.io/cmdx/configuration/#telemetry"
      elsif !EVENTS.include?(event)
        raise ArgumentError,
          "unknown telemetry event #{event.inspect}, must be one of #{EVENTS.inspect}. " \
          "See https://drexed.github.io/cmdx/configuration/#telemetry"
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
        raise UnknownEntryError,
          "unknown telemetry event #{event.inspect}, must be one of #{EVENTS.inspect}. " \
          "See https://drexed.github.io/cmdx/configuration/#telemetry"
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
        raise UnknownEntryError,
          "unknown telemetry event #{event.inspect}; registered: #{registry.keys.inspect}. " \
          "See https://drexed.github.io/cmdx/configuration/#telemetry"
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
