# frozen_string_literal: true

module CMDx
  # Registry for managing callbacks that can be executed at various points during task execution.
  #
  # Callbacks are organized by type and can be registered with optional conditions and options.
  # Each callback type represents a specific execution phase or outcome.
  class CallbackRegistry

    TYPES = %i[
      before_validation
      before_execution
      on_complete
      on_interrupted
      on_executed
      on_success
      on_skipped
      on_failed
      on_good
      on_bad
    ].freeze

    # @return [Hash<Symbol, Set>] The internal registry mapping callback types to sets of callables
    attr_reader :registry
    alias to_h registry

    # @param registry [Hash] Initial registry hash, defaults to empty
    def initialize(registry = {})
      @registry = registry
    end

    # Creates a deep copy of the registry with duplicated callable sets
    #
    # @return [CallbackRegistry] A new instance with duplicated registry contents
    def dup
      self.class.new(registry.transform_values(&:dup))
    end

    # Registers one or more callables for a specific callback type
    #
    # @param type [Symbol] The callback type from TYPES
    # @param callables [Array<#call>] Callable objects to register
    # @param options [Hash] Options to pass to the callback
    # @option options [Hash] :if Condition hash for conditional execution
    # @option options [Hash] :unless Inverse condition hash for conditional execution
    # @param block [Proc] Optional block to register as a callable
    #
    # @return [CallbackRegistry] self for method chaining
    #
    # @raise [ArgumentError] When type is not a valid callback type
    #
    # @example Register a method callback
    #   registry.register(:before_execution, :validate_inputs)
    # @example Register a block with conditions
    #   registry.register(:on_success, if: { status: :completed }) do |task|
    #     task.log("Success callback executed")
    #   end
    def register(type, *callables, **options, &block)
      callables << block if block_given?

      registry[type] ||= Set.new
      registry[type] << [callables, options]
      self
    end

    # Removes one or more callables for a specific callback type
    #
    # @param type [Symbol] The callback type from TYPES
    # @param callables [Array<#call>] Callable objects to remove
    # @param options [Hash] Options that were used during registration
    # @param block [Proc] Optional block to remove
    #
    # @return [CallbackRegistry] self for method chaining
    #
    # @example Remove a specific callback
    #   registry.deregister(:before_execution, :validate_inputs)
    def deregister(type, *callables, **options, &block)
      callables << block if block_given?
      return self unless registry[type]

      registry[type].delete([callables, options])
      registry.delete(type) if registry[type].empty?
      self
    end

    # Invokes all registered callbacks for a given type
    #
    # @param type [Symbol] The callback type to invoke
    # @param task [Task] The task instance to pass to callbacks
    #
    # @return [void]
    #
    # @raise [TypeError] When type is not a valid callback type
    #
    # @example Invoke all before_execution callbacks
    #   registry.invoke(:before_execution, task)
    def invoke(type, task)
      raise TypeError, "unknown callback type #{type.inspect}" unless TYPES.include?(type)

      Array(registry[type]).each do |callables, options|
        next unless Utils::Condition.evaluate(task, options, task)

        Array(callables).each { |callable| Utils::Call.invoke(task, callable) }
      end
    end

  end
end
