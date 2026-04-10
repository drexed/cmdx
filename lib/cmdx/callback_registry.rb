# frozen_string_literal: true

module CMDx
  # Registry of lifecycle callbacks organized by type.
  # Uses copy-on-write for safe inheritance across task classes.
  class CallbackRegistry

    # @rbs TYPES: Array[Symbol]
    TYPES = %i[
      before_validation
      before_execution
      on_success
      on_skipped
      on_failed
      on_complete
      on_interrupted
      on_executed
      on_good
      on_bad
    ].freeze

    # @rbs @callbacks: Hash[Symbol, Array[untyped]]
    attr_reader :callbacks

    # @rbs (?Hash[Symbol, Array[untyped]]? callbacks) -> void
    def initialize(callbacks = nil)
      @callbacks = callbacks || TYPES.to_h { |t| [t, []] }
    end

    # Registers a callback for a lifecycle type.
    #
    # @param type [Symbol] the callback type
    # @param callable [Symbol, Proc, Object] the callable
    # @param options [Hash] condition options (:if, :unless)
    #
    # @rbs (Symbol type, untyped callable, **untyped options) -> void
    def register(type, callable, **options)
      callbacks[type] << { callable:, **options }
    end

    # Returns all registered callbacks for a type.
    #
    # @param type [Symbol] the callback type
    #
    # @return [Array<Hash>] callback entries
    #
    # @rbs (Symbol type) -> Array[Hash[Symbol, untyped]]
    def for_type(type)
      callbacks.fetch(type, EMPTY_ARRAY)
    end

    # Invokes all callbacks for a type.
    #
    # @param type [Symbol] the callback type
    # @param task [Task] the task instance
    # @param result [Result] the result instance
    #
    # @rbs (Symbol type, untyped task, untyped result) -> void
    def invoke(type, task, result)
      for_type(type).each do |entry|
        next unless evaluate_conditions(entry, task)

        Utils::Call.invoke_callback(entry[:callable], task, result)
      end
    end

    # @return [Boolean] true if any callbacks are registered
    #
    # @rbs () -> bool
    def any?
      callbacks.any? { |_type, list| !list.empty? }
    end

    # @return [CallbackRegistry] a duplicated registry for child classes
    #
    # @rbs () -> CallbackRegistry
    def for_child
      duped = callbacks.transform_values(&:dup)
      self.class.new(duped)
    end

    private

    # @rbs (Hash[Symbol, untyped] entry, untyped task) -> bool
    def evaluate_conditions(entry, task) # rubocop:disable Naming/PredicateMethod
      return false if entry[:if] && !Utils::Condition.truthy?(entry[:if], task)
      return false if entry[:unless] && !Utils::Condition.falsy?(entry[:unless], task)

      true
    end

  end
end
