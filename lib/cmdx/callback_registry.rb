# frozen_string_literal: true

module CMDx
  ##
  # The CallbackRegistry collection provides a lifecycle callback system that executes
  # registered callbacks at specific points during task execution. Callbacks can be
  # conditionally executed based on task state and support both method references
  # and callable objects.
  #
  # The CallbackRegistry collection extends Hash to provide specialized functionality for
  # managing collections of callback definitions within CMDx tasks. It handles
  # callback registration, conditional execution, and inspection.
  #
  # @example Basic callback usage
  #   callback_registry = CallbackRegistry.new
  #   callback_registry.register(:before_validation, :check_permissions)
  #   callback_registry.register(:on_success, :log_success, if: :important?)
  #   callback_registry.register(:on_failure, proc { alert_admin }, unless: :test_env?)
  #
  #   callback_registry.call(task, :before_validation)
  #
  # @example Hash-like operations
  #   callback_registry[:before_validation] = [[:check_permissions, {}]]
  #   callback_registry.keys  # => [:before_validation]
  #   callback_registry.empty?  # => false
  #   callback_registry.each { |callback_name, callbacks| puts "#{callback_name}: #{callbacks}" }
  #
  # @see Callback Base callback execution class
  # @see Task Task lifecycle callbacks
  # @since 1.0.0
  class CallbackRegistry < Hash

    ##
    # Initializes a new CallbackRegistry.
    #
    # @param registry [CallbackRegistry, Hash, nil] Optional registry to copy from
    #
    # @example Initialize empty registry
    #   registry = CallbackRegistry.new
    #
    # @example Initialize with existing registry
    #   global_callbacks = CallbackRegistry.new
    #   task_callbacks = CallbackRegistry.new(global_callbacks)
    def initialize(registry = nil)
      super()

      registry&.each do |callback_type, callback_definitions|
        self[callback_type] = callback_definitions.dup
      end
    end

    # Registers a callback for the given callback type.
    #
    # @param callback [Symbol] The callback type (e.g., :before_validation, :on_success)
    # @param callables [Array<Symbol, Proc, #call>] Methods or callables to execute
    # @param options [Hash] Conditions for callback execution
    # @option options [Symbol, Proc, #call] :if condition that must be truthy
    # @option options [Symbol, Proc, #call] :unless condition that must be falsy
    # @param block [Proc] Block to execute as part of the callback
    # @return [CallbackRegistry] self for method chaining
    #
    # @example Register method callback
    #   registry.register(:before_validation, :check_permissions)
    #
    # @example Register conditional callback
    #   registry.register(:on_failure, :alert_admin, if: :critical?)
    #
    # @example Register proc callback
    #   registry.register(:on_success, proc { log_completion })
    def register(callback, *callables, **options, &block)
      callables << block if block_given?
      (self[callback] ||= []).push([callables, options]).uniq!
      self
    end

    # Executes all callbacks registered for a specific callback type on the given task.
    # Each callback is evaluated for its conditions (if/unless) before execution.
    #
    # @param task [Task] The task instance to execute callbacks on
    # @param callback [Symbol] The callback type to execute (e.g., :before_validation, :on_success)
    # @return [void]
    #
    # @example Execute callbacks
    #   registry.call(task, :before_validation)
    #
    # @example Execute conditional callbacks
    #   # Only executes if task.critical? returns true
    #   registry.call(task, :on_failure) # where registry has on_failure :alert, if: :critical?
    def call(task, callback)
      return unless key?(callback)

      Array(self[callback]).each do |callables, options|
        next unless task.__cmdx_eval(options)

        Array(callables).each do |c|
          if c.is_a?(Callback)
            c.call(task, callback)
          else
            task.__cmdx_try(c)
          end
        end
      end
    end

  end
end
