# frozen_string_literal: true

module CMDx
  # Registry for managing callback definitions and execution within tasks.
  #
  # This registry handles the registration and execution of callbacks at various
  # points in the task lifecycle, including validation, execution, and outcome
  # handling phases.
  class CallbackRegistry

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

    # @return [Hash] hash containing callback type keys and callback definition arrays
    attr_reader :registry

    # Initializes a new callback registry.
    #
    # @param registry [Hash] initial registry hash with callback definitions
    #
    # @return [CallbackRegistry] a new callback registry instance
    #
    # @example Creating an empty registry
    #   CallbackRegistry.new
    #
    # @example Creating a registry with initial callbacks
    #   CallbackRegistry.new(before_execution: [[:my_callback, {}]])
    def initialize(registry = {})
      @registry = registry.to_h
    end

    # Registers one or more callbacks for a specific type.
    #
    # @param type [Symbol] the callback type to register
    # @param callables [Array<Object>] callable objects to register
    # @param options [Hash] options for conditional callback execution
    # @param block [Proc] optional block to register as a callback
    #
    # @return [CallbackRegistry] returns self for method chaining
    #
    # @example Registering a symbol callback
    #   registry.register(:before_execution, :setup_database)
    #
    # @example Registering a Proc callback
    #   registry.register(:on_good, ->(task) { puts "Task completed: #{task.name}" })
    #
    # @example Registering a Callback class
    #   registry.register(:after_validation, NotificationCallback)
    #
    # @example Registering multiple callbacks with options
    #   registry.register(:on_good, :send_notification, :log_success, if: -> { Rails.env.production? })
    #
    # @example Registering a block callback
    #   registry.register(:after_validation) { |task| puts "Validation complete" }
    def register(type, *callables, **options, &block)
      callables << block if block_given?
      (registry[type] ||= []).push([callables, options]).uniq!
      self
    end

    # Executes all registered callbacks for a specific type.
    #
    # @param task [Task] the task instance to execute callbacks on
    # @param type [Symbol] the callback type to execute
    #
    # @return [void]
    #
    # @raise [UnknownCallbackError] when the callback type is not recognized
    #
    # @example Executing before_validation callbacks
    #   registry.call(task, :before_validation)
    #
    # @example Executing outcome callbacks
    #   registry.call(task, :on_good)
    def call(task, type)
      raise UnknownCallbackError, "unknown callback #{type}" unless TYPES.include?(type)

      Array(registry[type]).each do |callables, options|
        next unless task.cmdx_eval(options)

        Array(callables).each do |callable|
          case callable
          when Symbol, String, Proc
            task.cmdx_try(callable)
          else
            callable.call(task)
          end
        end
      end
    end

    # Returns a hash representation of the registry.
    #
    # @return [Hash] a deep copy of the registry hash
    #
    # @example Getting registry contents
    #   registry.to_h
    #   #=> { before_execution: [[:setup, {}]], on_good: [[:notify, { if: -> { true } }]] }
    def to_h
      registry.transform_values(&:dup)
    end

  end
end
