# frozen_string_literal: true

module CMDx
  ##
  # The CallbackRegistry provides a lifecycle callback system that executes
  # registered callbacks at specific points during task execution. Callbacks can be
  # conditionally executed based on task state and support both method references
  # and callable objects.
  #
  # The CallbackRegistry manages collections of callback definitions within CMDx tasks,
  # handling callback registration, conditional execution, and inspection. Unlike a
  # traditional Hash, it provides specialized functionality for managing callback
  # lifecycles with built-in condition evaluation.
  #
  # @example Basic callback usage
  #   callback_registry = CallbackRegistry.new
  #   callback_registry.register(:before_validation, :check_permissions)
  #   callback_registry.register(:on_success, :log_success, if: :important?)
  #   callback_registry.register(:on_failure, proc { alert_admin }, unless: :test_env?)
  #
  #   callback_registry.call(task, :before_validation)
  #
  # @example Inspecting registered callbacks
  #   callback_registry.to_h.keys  # => [:before_validation, :on_success, :on_failure]
  #   callback_registry.to_h[:on_success]  # => [[[:log_success], { if: :important? }]]
  #
  # @example Copying and extending registries
  #   base_registry = CallbackRegistry.new
  #   base_registry.register(:before_validation, :check_auth)
  #
  #   extended_registry = CallbackRegistry.new(base_registry)
  #   extended_registry.register(:before_validation, :additional_check)
  #
  # @see Callback Base callback execution class
  # @see Task Task lifecycle callbacks
  # @since 1.0.0
  class CallbackRegistry

    ##
    # Available callback types for task lifecycle events.
    # Callbacks are executed in a specific order during task execution.
    #
    # Includes validation callbacks (:before_validation, :after_validation),
    # execution callbacks (:before_execution, :after_execution, :on_executed),
    # state callbacks (:on_good, :on_bad), and dynamic callbacks based on
    # Result statuses and states.
    #
    # @return [Array<Symbol>] frozen array of available callback names
    TYPES = [
      :before_validation,
      :after_validation,
      :before_execution,
      :after_execution,
      :on_executed,
      :on_good,
      :on_bad,
      *Result::STATUSES.map { |s| :"on_#{s}" },
      *Result::STATES.map { |s| :"on_#{s}" }
    ].freeze

    ##
    # @!attribute [r] registry
    #   The internal hash storing callback definitions
    #   @return [Hash] hash containing callback type keys and callback definition arrays
    attr_reader :registry

    ##
    # Initializes a new CallbackRegistry.
    #
    # Creates a new registry that can optionally copy callbacks from an existing
    # registry or hash. When copying, callback definitions are duplicated to ensure
    # independence between registries.
    #
    # @param registry [CallbackRegistry, Hash, nil] Optional registry to copy from
    #
    # @example Initialize empty registry
    #   registry = CallbackRegistry.new
    #
    # @example Initialize with existing registry
    #   global_callbacks = CallbackRegistry.new
    #   global_callbacks.register(:before_validation, :check_auth)
    #   task_callbacks = CallbackRegistry.new(global_callbacks)
    #
    # @example Initialize with hash
    #   hash_callbacks = { before_validation: [[:check_permissions, {}]] }
    #   registry = CallbackRegistry.new(hash_callbacks)
    def initialize(registry = {})
      @registry = registry.to_h
    end

    ##
    # Registers a callback for the given callback type.
    #
    # Callbacks are stored as arrays of [callables_array, options_hash] pairs.
    # Multiple callables can be registered for the same callback type and will
    # be executed in registration order. Duplicate registrations are automatically
    # prevented.
    #
    # @param type [Symbol] The callback type (e.g., :before_validation, :on_success)
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
    # @example Register multiple callables
    #   registry.register(:on_success, :log_completion, :send_notification)
    #
    # @example Register proc callback
    #   registry.register(:on_success, proc { log_completion })
    #
    # @example Register with block
    #   registry.register(:before_validation) { |task| task.setup_context }
    #
    # @example Chain registrations
    #   registry.register(:before_validation, :check_auth)
    #           .register(:on_success, :log_success)
    #           .register(:on_failure, :handle_error)
    def register(type, *callables, **options, &block)
      callables << block if block_given?
      (registry[type] ||= []).push([callables, options]).uniq!
      self
    end

    ##
    # Executes all callbacks registered for a specific callback type on the given task.
    #
    # Each callback definition is evaluated for its conditions (if/unless) before execution.
    # Callables are executed in registration order. Callback instances are called directly,
    # while other callables are executed through the task's __cmdx_try method.
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
    #
    # @see Task#__cmdx_eval
    # @see Task#__cmdx_try
    def call(task, callback)
      return unless registry.key?(callback)

      Array(registry[callback]).each do |callables, options|
        next unless task.__cmdx_eval(options)

        Array(callables).each do |callable|
          if callable.is_a?(Callback)
            callable.call(task, callback)
          else
            task.__cmdx_try(callable)
          end
        end
      end
    end

    ##
    # Returns a hash representation of the complete callback registry.
    #
    # Creates a duplicate of the internal registry hash containing all
    # registered callbacks. Useful for introspection, serialization,
    # or debugging purposes. The returned hash maps callback type symbols
    # to arrays of [callables_array, options_hash] pairs.
    #
    # @return [Hash] duplicated hash of all registered callbacks
    #
    # @example Inspect available callbacks
    #   registry = CallbackRegistry.new
    #   registry.register(:before_validation, :check_permissions)
    #   registry.register(:on_success, :log_success, if: :important?)
    #
    #   callbacks = registry.to_h
    #   callbacks.keys  # => [:before_validation, :on_success]
    #   callbacks[:on_success]  # => [[[:log_success], { if: :important? }]]
    #
    # @example Use in configuration or serialization
    #   config = {
    #     callbacks: registry.to_h,
    #     other_settings: {}
    #   }
    def to_h
      registry.dup.transform_values(&:dup)
    end

  end
end
