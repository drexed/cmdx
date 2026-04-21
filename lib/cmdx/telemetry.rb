# frozen_string_literal: true

module CMDx
  # Pub/sub for runtime lifecycle events (see {EVENTS}). Subscribers are
  # callables receiving an {Event} data object. Runtime emits events only when
  # subscribers are registered so telemetry has zero cost when unused.
  class Telemetry

    # Immutable event payload passed to subscribers.
    Event = Data.define(:cid, :root, :type, :task, :tid, :name, :payload, :timestamp)

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

    def initialize_copy(source)
      @registry = source.registry.transform_values(&:dup)
    end

    # Registers a subscriber for `event`.
    #
    # @param event [Symbol] one of {EVENTS}
    # @param callable [#call, nil] subscriber callable; pass either this or a block
    # @yieldparam event [Event]
    # @return [Telemetry] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are provided, when
    #   the subscriber isn't callable, or when `event` is unknown
    def subscribe(event, callable = nil, &block)
      subscriber = callable || block

      if callable && block
        raise ArgumentError, "provide either a callable or a block, not both"
      elsif !subscriber.respond_to?(:call)
        raise ArgumentError, "subscriber must respond to #call"
      elsif !EVENTS.include?(event)
        raise ArgumentError, "unknown event #{event.inspect}, must be one of #{EVENTS.join(', ')}"
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
    # @raise [ArgumentError] when `event` is unknown
    def unsubscribe(event, callable)
      raise ArgumentError, "unknown event #{event.inspect}, must be one of #{EVENTS.join(', ')}" unless EVENTS.include?(event)

      return self unless subscribed?(event)

      registry[event].delete(callable)
      registry.delete(event) if registry[event].empty?
      self
    end

    # @param event [Symbol]
    # @return [Boolean] true when at least one subscriber exists for `event`
    def subscribed?(event)
      registry.key?(event)
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
      return unless (subscribers = registry[event])

      subscribers.each { |s| s.call(payload) }
    end

  end
end
