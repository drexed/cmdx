# frozen_string_literal: true

module CMDx
  # Registry of lifecycle callbacks invoked by Runtime. Callbacks can be
  # method names (Symbols dispatched via `task.send`), blocks/Procs
  # (`instance_exec`'d on the task), or arbitrary `#call` objects.
  #
  # Each registration may carry `:if` / `:unless` gates (Symbol, Proc, or
  # any `#call`-able). Gates are evaluated against the task before the
  # callback is invoked; non-passing gates skip the callback silently.
  class Callbacks

    # Callback event names Runtime dispatches.
    EVENTS = Set[
      :before_validation,
      :before_execution,
      :after_execution,
      :on_complete,
      :on_interrupted,
      :on_success,
      :on_skipped,
      :on_failed,
      :on_ok,
      :on_ko
    ].freeze

    attr_reader :registry

    def initialize
      @registry = {}
    end

    def initialize_copy(source)
      @registry = source.registry.transform_values(&:dup)
    end

    # Adds a callback for `event`.
    #
    # @param event [Symbol] one of {EVENTS}
    # @param callable [Symbol, #call, nil] method name or callable; pass either this or a block
    # @param options [Hash{Symbol => Object}]
    # @option options [Symbol, Proc, #call] :if   gate that must evaluate truthy
    # @option options [Symbol, Proc, #call] :unless gate that must evaluate falsy
    # @yield the callback body
    # @return [Callbacks] self for chaining
    # @raise [ArgumentError] when both `callable` and a block are given, when the
    #   callback type is invalid, or when `event` is unknown
    def register(event, callable = nil, **options, &block)
      callback = callable || block

      if callable && block
        raise ArgumentError, "provide either a callable or a block, not both"
      elsif !callback.is_a?(Symbol) && !callback.respond_to?(:call)
        raise ArgumentError, "callback must be a Symbol or respond to #call"
      elsif !EVENTS.include?(event)
        raise ArgumentError, "unknown event #{event.inspect}, must be one of #{EVENTS.join(', ')}"
      end

      (registry[event] ||= []) << [callback, options.freeze]
      self
    end

    # Drops callbacks registered for `event`. With no `callable`, removes
    # every callback for `event`. With a `callable`, removes only the
    # entries whose callback matches `callable` by `==` (works for Symbol
    # method names, classes/modules, and any callable held by reference).
    # When the last entry for `event` is removed, the key itself is dropped.
    #
    # @param event [Symbol] one of {EVENTS}
    # @param callable [Symbol, #call, nil] optional specific callback to remove
    # @return [Callbacks] self for chaining
    # @raise [ArgumentError] when `event` is unknown
    def deregister(event, callable = nil)
      raise ArgumentError, "unknown event #{event.inspect}, must be one of #{EVENTS.join(', ')}" unless EVENTS.include?(event)

      if callable.nil?
        registry.delete(event)
      elsif (entries = registry[event])
        entries.reject! { |cb, _opts| cb == callable }
        registry.delete(event) if entries.empty?
      end

      self
    end

    # @return [Boolean]
    def empty?
      registry.empty?
    end

    # @return [Integer] number of distinct events with callbacks
    def size
      registry.size
    end

    # @return [Integer] total callbacks across all events
    def count
      registry.each_value.sum(&:size)
    end

    # Fires each callback registered for `event` against `task`. Skips any
    # callback whose `:if`/`:unless` gates fail.
    #
    # @param event [Symbol]
    # @param task [Task]
    # @return [void]
    # @raise [ArgumentError] when a callback is neither a Symbol nor responds to `#call`
    def process(event, task)
      return unless (callbacks = registry[event])

      callbacks.each do |callable, options|
        next unless Util.satisfied?(options[:if], options[:unless], task)

        case callable
        when Symbol
          task.send(callable)
        when Proc
          task.instance_exec(task, &callable)
        else
          next callable.call(task) if callable.respond_to?(:call)

          raise ArgumentError, "callback must be a Symbol, Proc, or respond to #call"
        end
      end
    end

  end
end
